//
//  TimerSessionCompletionSheet.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 06.01.26.
//

import SwiftUI
import SwiftData

struct TimerSessionCompletionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var timer: ReadingTimerManager

    let book: Book?
    let pending: ReadingTimerManager.PendingCompletion

    @State private var pagesText: String = ""
    @State private var noteText: String = ""
    @State private var lastError: String? = nil
    @State private var challengeProgressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]

    @AppStorage(ChallengePreferencesStorageKey.enabledKinds) private var enabledKindsRaw: String = ChallengePreferencesStore.defaultEnabledKindsRaw
    @AppStorage(ChallengePreferencesStorageKey.preset) private var presetRaw: String = ChallengePreferencesStore.defaultPresetRaw

    @Query(sort: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)])
    private var challenges: [ChallengeRecord]

    private var challengePreferences: ChallengePreferences {
        ChallengePreferencesStore.preferences(enabledKindsRaw: enabledKindsRaw, presetRaw: presetRaw)
    }

    var body: some View {
        let challengeSignature = ChallengeSummarySignature(challenges: challenges)
        let preferencesSignature = challengePreferences.storageSignature
        let pendingImpact = pendingChallengeImpact

        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Dauer", systemImage: "timer")
                        Spacer()
                        Text(ReadingTimerManager.formatDuration(pending.durationSeconds))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Start")
                        Spacer()
                        Text(Self.dateTimeFormatter.string(from: pending.startedAt))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Ende")
                        Spacer()
                        Text(Self.dateTimeFormatter.string(from: pending.endedAt))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if pending.wasAutoStopped {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "moon.zzz")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Stop")
                                    .font(.subheadline.weight(.semibold))
                                if let m = pending.autoStopMinutes {
                                    Text("Die Session wurde nach \(m) Minuten Inaktivität automatisch beendet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Die Session wurde automatisch beendet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if let err = lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Session")
                }

                if let pendingImpact {
                    Section {
                        ChallengeSessionImpactBanner(impact: pendingImpact)
                    } header: {
                        Text("Challenge-Impact")
                    } footer: {
                        Text("Vorschau auf Basis der aktuellen aktiven Challenges. Beim Speichern wird der echte Fortschritt erneut berechnet.")
                    }
                }

                Section("Optional") {
                    TextField(pagesFieldPlaceholder, text: $pagesText)
                        .keyboardType(.numberPad)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                }

                if book == nil {
                    Section {
                        Text("Dieses Buch ist nicht mehr verfügbar. Du kannst die Session verwerfen oder nur die Dauer notieren (aktuell wird nichts gespeichert).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(safeBookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbruch") {
                        timer.discardPendingCompletion()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(book == nil)
                }
            }
        }
        .task(id: challengeSignature) {
            await refreshChallengeProgress()
        }
        .task(id: preferencesSignature) {
            await refreshChallengeProgress()
        }
        .onDisappear {
            // If the user dismisses the sheet interactively (swipe down),
            // treat it like "Abbruch" (i.e. nothing saved).
            if timer.pendingCompletion?.id == pending.id {
                timer.discardPendingCompletion()
            }
        }
    }

    private var safeBookTitle: String {
        let t = (book?.title ?? pending.bookTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Session" : t
    }

    private var pagesFieldPlaceholder: String {
        if let remainingPagesForBook {
            return "Seiten gelesen (max. \(remainingPagesForBook))"
        }
        return "Seiten gelesen"
    }

    private var remainingPagesForBook: Int? {
        guard let book else { return nil }
        return ReadingAttemptSessionCoordinator.currentRemainingPages(
            for: book,
            allSessions: book.readingSessionsSafe
        )
    }

    @MainActor
    private var pendingChallengeImpact: ChallengeSessionImpact? {
        guard let book else { return nil }

        let pages = parsePositiveInt(pagesText)
        let timing = ReadingSessionLogging.Timing(endedAt: pending.endedAt, durationSeconds: pending.durationSeconds)
        let state = ReadingSessionLogging.BookState(book: book)
        let activeAttempt = book.activeReadingAttempt
        let scopedSessions = activeAttempt.map { attempt in
            ReadingAttemptSessionCoordinator.sessions(for: attempt, allSessions: book.readingSessionsSafe)
        } ?? book.readingSessionsSafe
        let isLegacySupplement = book.status == .finished && activeAttempt == nil
        let didMarkBookFinished: Bool

        let planResult = ReadingSessionLogging.plan(
            bookState: state,
            existingSessions: scopedSessions,
            timing: timing,
            pages: pages,
            note: nil,
            allowsFinishedBookSupplement: isLegacySupplement
        )

        switch planResult {
        case .failure:
            didMarkBookFinished = false
        case .success(let plan):
            didMarkBookFinished = plan.didMarkFinished
        }

        let contribution = ChallengeSessionContribution(
            bookID: book.id,
            startedAt: pending.startedAt,
            endedAt: pending.endedAt,
            durationSeconds: pending.durationSeconds,
            pagesRead: pages,
            didMarkBookFinished: didMarkBookFinished,
            hasNote: !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        return ChallengeSessionImpactBuilder.makePendingSessionImpact(
            challenges: visibleActiveChallenges(),
            progressBeforeByID: challengeProgressByID,
            contribution: contribution
        )
    }

    @MainActor
    private func refreshChallengeProgress() async {
        challengeProgressByID = await ChallengeRefreshCoordinator.computeProgressMap(
            for: visibleActiveChallenges(),
            modelContext: modelContext
        )
    }

    @MainActor
    private func visibleActiveChallenges(now: Date = Date()) -> [ChallengeRecord] {
        let enabledKindSet = Set(ChallengePreferences.normalizedKinds(challengePreferences.enabledKinds))
        let active = challenges.filter { record in
            record.periodStart <= now && record.periodEnd > now &&
            (enabledKindSet.contains(record.kind) || (record.isCompleted && !record.isClaimed))
        }
        return ChallengeDuplicateResolver.deduplicatedRecords(active)
    }

    @MainActor
    private func save() async {
        guard let book else {
            lastError = "Buch nicht gefunden – kann nicht speichern."
            return
        }

        lastError = nil

        let pages = parsePositiveInt(pagesText)
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note: String? = trimmedNote.isEmpty ? nil : trimmedNote

        let timing = ReadingSessionLogging.Timing(endedAt: pending.endedAt, durationSeconds: pending.durationSeconds)
        let activeAttempt = ReadingAttemptSessionCoordinator.ensureActiveAttemptForSessionIfNeeded(
            book: book,
            startedAt: timing.startedAt,
            now: pending.endedAt,
            insertAttempt: { modelContext.insert($0) }
        )
        let state = ReadingSessionLogging.BookState(book: book)
        let scopedSessions = activeAttempt.map { attempt in
            ReadingAttemptSessionCoordinator.sessions(for: attempt, allSessions: book.readingSessionsSafe)
        } ?? book.readingSessionsSafe
        let isLegacySupplement = book.status == .finished && activeAttempt == nil

        let planResult = ReadingSessionLogging.plan(
            bookState: state,
            existingSessions: scopedSessions,
            timing: timing,
            pages: pages,
            note: note,
            allowsFinishedBookSupplement: isLegacySupplement
        )

        var session: ReadingSession? = nil
        var sessionPlan: ReadingSessionLogging.Plan? = nil
        var didMarkBookFinished = false

        switch planResult {
        case .failure(let err):
            lastError = err.message
            return
        case .success(let plan):
            plan.apply(to: book)
            session = plan.makeSession(book: book)
            sessionPlan = plan
            didMarkBookFinished = plan.didMarkFinished
        }

        guard let session else {
            lastError = "Konnte Session nicht vorbereiten."
            return
        }

        modelContext.insert(session)
        if let sessionPlan {
            ReadingAttemptSessionCoordinator.attach(
                session: session,
                to: activeAttempt,
                plan: sessionPlan,
                book: book,
                now: pending.endedAt
            )
        }

        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte Session nicht speichern: " + error.localizedDescription
        } else {
            lastError = nil
            await ChallengeRefreshCoordinator.refreshAfterReadingSessionSave(
                modelContext: modelContext,
                bookID: book.id,
                session: session,
                didMarkBookFinished: didMarkBookFinished
            )

            timer.discardPendingCompletion()
            dismiss()
        }
    }

    private func parsePositiveInt(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let val = Int(trimmed), val > 0 else { return nil }
        return val
    }

    private static let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
