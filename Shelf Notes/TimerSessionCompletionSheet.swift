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
        let didMarkBookFinished: Bool

        let planResult = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: book.readingSessionsSafe,
            timing: timing,
            pages: pages,
            note: nil
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
            pagesRead: pages,
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

        let pages = parsePositiveInt(pagesText)
        let timing = ReadingSessionLogging.Timing(endedAt: pending.endedAt, durationSeconds: pending.durationSeconds)
        let saveResult = ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: modelContext,
            timing: timing,
            pages: pages,
            note: noteText,
            allSessions: book.readingSessionsSafe,
            now: pending.endedAt
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

    private func parsePositiveInt(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let val = Int(trimmed), val > 0 else { return nil }
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
