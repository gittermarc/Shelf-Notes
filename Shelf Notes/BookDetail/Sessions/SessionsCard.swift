//
//  SessionsCard.swift
//  Shelf Notes
//
//  Split out of the former BookDetailSessionsViews.swift
//  (No functional changes)
//

import SwiftUI
import SwiftData

struct SessionsCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var timer: ReadingTimerManager

    let book: Book
    let onShowAll: () -> Void

    @State private var showingQuickLogSheet: Bool = false
    @State private var lastError: String? = nil
    @State private var challengeProgressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]
    @State private var challengeRefreshSeed: Int = 0
    @State private var challengeSourceSnapshot: ChallengeSourceSnapshot = .empty
    @State private var latestChallengeImpact: ChallengeSessionImpact?
    @State private var showingRereadStartSheet: Bool = false
    @State private var pendingRereadAction: RereadStartAction?

    @AppStorage(ChallengePreferencesStorageKey.enabledKinds) private var enabledKindsRaw: String = ChallengePreferencesStore.defaultEnabledKindsRaw
    @AppStorage(ChallengePreferencesStorageKey.preset) private var presetRaw: String = ChallengePreferencesStore.defaultPresetRaw
    @AppStorage(AppearanceStorageKey.useSystemTint) private var useSystemTint: Bool = true
    @AppStorage(AppearanceStorageKey.tintColorHex) private var tintColorHex: String = "#007AFF"

    @Query private var sessions: [ReadingSession]

    private let previewLimit: Int = 8

    private var challengePreferences: ChallengePreferences {
        ChallengePreferencesStore.preferences(enabledKindsRaw: enabledKindsRaw, presetRaw: presetRaw)
    }

    private var sessionActionHints: [ChallengeActionHint] {
        let preferences = challengePreferences
        let dashboard = ChallengeDashboardBuilder.make(
            challenges: challengeSourceSnapshot.dashboardRecords,
            progressByID: challengeProgressByID,
            enabledKinds: preferences.enabledKinds
        )

        return ChallengeActionHintBuilder.makeSessionHints(
            from: dashboard.sessionHintItems,
            bookTitle: safeTitle(book),
            remainingPages: remainingPagesForBook
        )
    }

    private var liveActivityAccentHex: String? {
        useSystemTint ? nil : tintColorHex
    }

    /// Remaining pages for the currently active reading attempt.
    /// Returns nil for legacy supplements and books without a valid page count.
    private var remainingPagesForBook: Int? {
        ReadingAttemptSessionCoordinator.currentRemainingPages(for: book, allSessions: sessions)
    }

    private var currentProgressSessions: [ReadingSession] {
        ReadingAttemptSessionCoordinator.progressSessions(for: book, allSessions: sessions)
    }

    private var sessionGroups: [ReadingSessionGroup] {
        ReadingSessionGrouping.makeGroups(book: book, sessions: sessions)
    }

    private var previewSessionGroups: [ReadingSessionGroup] {
        ReadingSessionGrouping.limitedGroups(sessionGroups, limit: previewLimit)
    }

    private var needsRereadChoice: Bool {
        book.status == .finished && book.activeReadingAttempt == nil
    }

    private var nextAttemptName: String {
        "\(book.nextReadingAttemptSequenceNumber). Durchgang"
    }

    init(book: Book, onShowAll: @escaping () -> Void) {
        self.book = book
        self.onShowAll = onShowAll

        let bookID = book.id
        _sessions = Query(
            filter: #Predicate<ReadingSession> { $0.book?.id == bookID },
            sort: [SortDescriptor(\ReadingSession.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        let preferences = challengePreferences
        let actionHints = sessionActionHints
        let refreshID = ChallengeActionHintRefreshID(
            challengeSignature: challengeSourceSnapshot.signature,
            refreshSeed: challengeRefreshSeed,
            preferencesSignature: preferences.storageSignature
        )

        BookDetailCard(title: "Lesesessions") {
            VStack(alignment: .leading, spacing: 12) {
                header

                ReadingProgressView(book: book, sessions: currentProgressSessions)

                if book.isRereading, let activeAttempt = book.activeReadingAttempt {
                    ActiveRereadStatusBanner(
                        attemptName: activeAttempt.displayName,
                        detailLine: activeRereadDetailLine
                    )
                } else if needsRereadChoice {
                    RereadReadyBanner {
                        pendingRereadAction = .timer
                        showingRereadStartSheet = true
                    }
                }

                if let latestChallengeImpact {
                    ChallengeSessionImpactBanner(impact: latestChallengeImpact)
                }

                if !actionHints.isEmpty {
                    ChallengeActionHintPanel(hints: actionHints)
                }

                if let err = lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if sessions.isEmpty {
                    emptyState
                } else {
                    GroupedSessionPreviewView(groups: previewSessionGroups) { session in
                        delete(session)
                    }

                    if sessions.count > previewLimit {
                        Button {
                            onShowAll()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Alle Sessions anzeigen")
                                Spacer()
                                Text("\(sessions.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuickLogSheet) {
            QuickSessionLogSheet(
                bookTitle: safeTitle(book),
                remainingPages: remainingPagesForBook,
                totalPages: (book.pageCount ?? 0) > 0 ? book.pageCount : nil,
                onCreate: { minutes, pages, note in
                    addSession(minutes: minutes, pages: pages, note: note)
                }
            )
        }
        .sheet(isPresented: $showingRereadStartSheet) {
            ReReadStartSheet(
                bookTitle: safeTitle(book),
                nextAttemptName: nextAttemptName,
                onStartNewAttempt: {
                    continueAfterRereadChoice(shouldStartNewAttempt: true)
                },
                onSupplementExistingCompletion: {
                    continueAfterRereadChoice(shouldStartNewAttempt: false)
                }
            )
        }
        .task(id: refreshID) {
            await refreshChallengeHints()
            await MainActor.run {
                refreshLiveActivitySnapshotIfNeeded()
            }
        }
        .onAppear {
            challengeRefreshSeed &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionsDidChange)) { _ in
            challengeRefreshSeed &+= 1
            refreshLiveActivitySnapshotIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .challengeSessionImpactDidChange)) { notification in
            guard let impact = notification.object as? ChallengeSessionImpact else { return }
            guard impact.bookID == book.id else { return }
            latestChallengeImpact = impact
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let active = timer.active, active.bookID == book.id {
                    if active.isPaused {
                        Text("Pausiert · " + ReadingTimerManager.formatDuration(timer.elapsedSeconds()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("Läuft gerade · " + timer.elapsedString(now: context.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } else if let active = timer.active, active.bookID != book.id {
                    Text((active.isPaused ? "Pausiert: " : "Läuft gerade: ") + active.bookTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !sessions.isEmpty {
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Logge deine Lesezeit pro Buch – super für Streaks & Statistiken.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                timerControls

                // ✅ Manuelles Hinzufügen nur, wenn gerade KEINE aktive Timer-Session läuft.
                if timer.active == nil {
                    Button {
                        requestQuickLog()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                            Text(needsRereadChoice ? "Nachtragen" : "Session")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Session hinzufügen")
                }
            }
        }
    }

    @ViewBuilder
    private var timerControls: some View {
        // ✅ Timer-Session: Icons statt “Start/Stop” (+ Pause)
        if let active = timer.active, active.bookID == book.id {
            if active.isPaused {
                iconCircleButton(systemName: "play.fill", tint: .green, accessibilityLabel: "Session fortsetzen") {
                    timer.resume()
                }
                iconCircleButton(systemName: "stop.fill", tint: .red, accessibilityLabel: "Session stoppen") {
                    timer.stop()
                }
            } else {
                iconCircleButton(systemName: "pause.fill", tint: .orange, accessibilityLabel: "Session pausieren") {
                    timer.pause()
                }
                iconCircleButton(systemName: "stop.fill", tint: .red, accessibilityLabel: "Session stoppen") {
                    timer.stop()
                }
            }
        } else if timer.active != nil {
            // Another book is currently running/paused → allow stop from here.
            iconCircleButton(systemName: "stop.fill", tint: .red, accessibilityLabel: "Aktive Session stoppen") {
                timer.stop()
            }
        } else {
            iconCircleButton(
                systemName: needsRereadChoice ? "arrow.triangle.2.circlepath" : "play.fill",
                tint: .green,
                accessibilityLabel: needsRereadChoice ? "Nochmal lesen" : "Session starten"
            ) {
                requestTimerStart()
            }
        }
    }

    private func iconCircleButton(
        systemName: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Noch keine Sessions")
                    .font(.subheadline)
                Text(
                    timer.active == nil
                    ? "Tippe auf ▶︎ (Timer) oder „+ Session“ (manuell)."
                    : "Es läuft gerade eine Session – stoppe sie oben, um manuell nachzutragen."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var summaryLine: String {
        let totalMinutes = sessions.reduce(0) { $0 + max(0, Int(round(Double($1.durationSeconds) / 60.0))) }
        if totalMinutes <= 0 {
            return "\(sessions.count) Sessions"
        }
        return "\(sessions.count) Sessions · \(totalMinutes) Min. gesamt"
    }

    private var activeRereadDetailLine: String {
        if let totalPages = ReadingSessionLogging.normalizedTotalPages(book.pageCount) {
            let pagesRead = ReadingSessionLogging.pagesReadTotal(in: currentProgressSessions)
            let clampedRead = min(max(0, pagesRead), totalPages)
            let remaining = max(0, totalPages - clampedRead)
            let percent = Int((Double(clampedRead) / Double(totalPages) * 100.0).rounded())
            return "\(percent) % · noch \(remaining) Seiten"
        }

        let pagesRead = ReadingSessionLogging.pagesReadTotal(in: currentProgressSessions)
        if pagesRead > 0 {
            return "\(pagesRead) Seiten im aktuellen Durchgang geloggt"
        }
        return "Der Fortschritt startet für diesen Durchgang neu."
    }

    private func requestQuickLog() {
        guard needsRereadChoice else {
            showingQuickLogSheet = true
            return
        }

        pendingRereadAction = .quickLog
        showingRereadStartSheet = true
    }

    @MainActor
    private func requestTimerStart() {
        guard needsRereadChoice else {
            startTimer()
            return
        }

        pendingRereadAction = .timer
        showingRereadStartSheet = true
    }

    @MainActor
    private func continueAfterRereadChoice(shouldStartNewAttempt: Bool) {
        lastError = nil
        let action = pendingRereadAction
        pendingRereadAction = nil
        showingRereadStartSheet = false

        if shouldStartNewAttempt {
            let now = Date()
            ReadingAttemptSessionCoordinator.startNewRereadAttempt(
                for: book,
                startedAt: now,
                now: now,
                insertAttempt: { modelContext.insert($0) }
            )
            if let error = modelContext.saveWithDiagnostics() {
                lastError = "Konnte neuen Lesedurchgang nicht starten: " + error.localizedDescription
                return
            }
        }

        Task { @MainActor in
            await Task.yield()

            switch action {
            case .timer:
                startTimer()
            case .quickLog:
                showingQuickLogSheet = true
            case .none:
                break
            }
        }
    }

    @MainActor
    private func startTimer() {
        let title = safeTitle(book)
        let liveActivitySnapshot = makeLiveActivitySnapshot(isPaused: false)
        lastError = timer.start(
            bookID: book.id,
            bookTitle: title,
            coverThumbnailData: book.userCoverData,
            liveActivitySnapshot: liveActivitySnapshot
        )
    }

    @MainActor
    private func refreshLiveActivitySnapshotIfNeeded() {
        guard timer.activeBookID == book.id else { return }
        timer.updateLiveActivitySnapshot(makeLiveActivitySnapshot(isPaused: timer.isPaused))
    }

    @MainActor
    private func makeLiveActivitySnapshot(isPaused: Bool) -> ReadingSessionLiveActivitySnapshot {
        ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: sessions,
            challengeHints: sessionActionHints,
            isPaused: isPaused,
            hasCover: book.userCoverData != nil,
            accentHex: liveActivityAccentHex
        )
    }

    @MainActor
    private func refreshChallengeHints() async {
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
    private func addSession(minutes: Int, pages: Int?, note: String?) {
        lastError = nil

        let m = max(0, minutes)
        guard m > 0 else {
            lastError = "Bitte eine Dauer > 0 Minuten eingeben."
            return
        }

        let seconds = m * 60
        let end = Date()
        let timing = ReadingSessionLogging.Timing(endedAt: end, durationSeconds: seconds)
        let saveResult = ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: modelContext,
            timing: timing,
            pages: pages,
            note: note,
            allSessions: sessions,
            now: end
        )

        switch saveResult {
        case .failure(let error):
            lastError = error.message
        case .success(let mutation):
            lastError = nil
            ChallengeRefreshCoordinator.requestRefreshAfterReadingSessionSave(
                modelContext: modelContext,
                mutation: mutation
            )
        }
    }

    @MainActor
    private func delete(_ session: ReadingSession) {
        let sessionSnapshot = SavedReadingSessionSnapshot(bookID: book.id, session: session)
        ReadingAttemptSessionCoordinator.detachBeforeDeleting(session)
        modelContext.delete(session)
        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte Session nicht löschen: " + error.localizedDescription
        } else {
            lastError = nil
            latestChallengeImpact = nil
            ChallengeRefreshCoordinator.requestRefreshAfterReadingSessionDelete(
                modelContext: modelContext,
                sessionSnapshot: sessionSnapshot
            )
        }
    }

    private func safeTitle(_ book: Book) -> String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Buch" : t
    }
}


private enum RereadStartAction: Sendable {
    case timer
    case quickLog
}


private struct ChallengeActionHintRefreshID: Hashable {
    let challengeSignature: ChallengeSummarySignature
    let refreshSeed: Int
    let preferencesSignature: String
}
