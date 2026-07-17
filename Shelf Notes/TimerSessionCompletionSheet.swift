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

    @State private var progressState = ReadingProgressInputState()
    @State private var noteText: String = ""
    @State private var lastError: String? = nil
    @State private var challengeProgressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]
    @State private var challengeSourceSnapshot: ChallengeSourceSnapshot = .empty

    @AppStorage(ChallengePreferencesStorageKey.enabledKinds) private var enabledKindsRaw: String = ChallengePreferencesStore.defaultEnabledKindsRaw
    @AppStorage(ChallengePreferencesStorageKey.preset) private var presetRaw: String = ChallengePreferencesStore.defaultPresetRaw

    private var challengePreferences: ChallengePreferences {
        ChallengePreferencesStore.preferences(enabledKindsRaw: enabledKindsRaw, presetRaw: presetRaw)
    }

    var body: some View {
        let challengeSignature = challengeSourceSnapshot.signature
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

                ReadingProgressInputView(
                    state: $progressState,
                    configuration: progressInputContext.configuration,
                    errorMessage: lastError
                )

                Section("Notiz") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                        .accessibilityLabel("Notiz zur Lesesession")
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
        .onChange(of: progressState) { _, _ in
            lastError = nil
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

    @MainActor
    private var progressInputContext: ReadingSessionProgressInputContext {
        guard let book else {
            let snapshot = ReadingProgressSnapshot.unknown(unit: .pages)
            return ReadingSessionProgressInputContext(
                source: ReadingSessionSource(origin: .timer),
                currentProgress: snapshot,
                configuration: ReadingProgressInputConfiguration(
                    unit: .pages,
                    currentProgress: snapshot,
                    sourceTitle: ReadingSourceSelection.physical.title,
                    isManuallyTracked: true
                )
            )
        }

        return ReadingSessionMutationService.makeProgressInputContext(
            book: book,
            allSessions: book.readingSessionsSafe,
            origin: .timer
        )
    }

    @MainActor
    private var pendingChallengeImpact: ChallengeSessionImpact? {
        guard let book else { return nil }

        let timing = ReadingSessionLogging.Timing(endedAt: pending.endedAt, durationSeconds: pending.durationSeconds)
        let didMarkBookFinished: Bool
        let submission = try? ReadingProgressInputBuilder.makeSubmission(
            state: progressState,
            configuration: progressInputContext.configuration,
            occurredAt: pending.endedAt
        ).get()

        let planResult = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: book.readingSessionsSafe,
            timing: timing,
            progressUpdate: submission?.progressUpdate,
            note: nil,
            source: progressInputContext.source,
            mutationMode: submission?.mutationMode ?? .standard
        )

        switch planResult {
        case .failure:
            didMarkBookFinished = false
        case .success(let mutationPlan):
            didMarkBookFinished = mutationPlan.plan.didMarkFinished
        }

        let contribution = ChallengeSessionContribution(
            bookID: book.id,
            startedAt: pending.startedAt,
            endedAt: pending.endedAt,
            durationSeconds: pending.durationSeconds,
            pagesRead: submission?.pagesDelta,
            didMarkBookFinished: didMarkBookFinished,
            hasNote: !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        return ChallengeSessionImpactBuilder.makePendingSessionImpact(
            challenges: challengeSourceSnapshot.activeRecords,
            progressBeforeByID: challengeProgressByID,
            contribution: contribution
        )
    }

    @MainActor
    private func refreshChallengeProgress() async {
        let snapshot = ChallengeSourceStore.makeSnapshot(
            modelContext: modelContext,
            enabledKinds: challengePreferences.enabledKinds,
            includeHistory: false
        )
        challengeProgressByID = await ChallengeRefreshCoordinator.computeProgressMap(
            for: snapshot.progressRecords,
            modelContext: modelContext
        )
        challengeSourceSnapshot = snapshot
    }

    @MainActor
    private func save() async {
        guard let book else {
            lastError = "Buch nicht gefunden – kann nicht speichern."
            return
        }

        lastError = nil

        let timing = ReadingSessionLogging.Timing(endedAt: pending.endedAt, durationSeconds: pending.durationSeconds)
        let submission: ReadingProgressInputSubmission
        switch ReadingProgressInputBuilder.makeSubmission(
            state: progressState,
            configuration: progressInputContext.configuration,
            occurredAt: pending.endedAt
        ) {
        case .failure(let error):
            lastError = error.message
            return
        case .success(let value):
            submission = value
        }

        let saveResult = ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: modelContext,
            timing: timing,
            progressUpdate: submission.progressUpdate,
            note: noteText,
            source: progressInputContext.source,
            mutationMode: submission.mutationMode,
            allSessions: book.readingSessionsSafe,
            now: pending.endedAt,
            externalEventIdentifier: nil
        )

        switch saveResult {
        case .failure(let error):
            lastError = error.message
        case .success(let mutation):
            lastError = nil
            timer.discardPendingCompletion()
            dismiss()

            ChallengeRefreshCoordinator.requestRefreshAfterReadingSessionSave(
                modelContext: modelContext,
                mutation: mutation
            )
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
