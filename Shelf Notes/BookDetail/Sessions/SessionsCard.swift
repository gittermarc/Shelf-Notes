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
    @State private var latestChallengeImpact: ChallengeSessionImpact?

    @Query private var sessions: [ReadingSession]

    @Query(sort: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)])
    private var challenges: [ChallengeRecord]

    private let previewLimit: Int = 8

    /// Remaining pages until the book is finished (based on logged sessions).
    /// Returns nil when the book has no valid total page count.
    private var remainingPagesForBook: Int? {
        ReadingSessionLogging.remainingPages(totalPages: book.pageCount, sessions: sessions)
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
        let challengeSignature = ChallengeSummarySignature(challenges: challenges)
        let dashboard = ChallengeDashboardBuilder.make(
            challenges: challenges,
            progressByID: challengeProgressByID
        )
        let actionHints = ChallengeActionHintBuilder.makeSessionHints(
            from: dashboard.activeItems,
            bookTitle: safeTitle(book),
            remainingPages: remainingPagesForBook
        )
        let refreshID = ChallengeActionHintRefreshID(
            challengeSignature: challengeSignature,
            refreshSeed: challengeRefreshSeed
        )

        BookDetailCard(title: "Lesesessions") {
            VStack(alignment: .leading, spacing: 12) {
                header

                ReadingProgressView(book: book, sessions: sessions)

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
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(sessions.prefix(previewLimit)), id: \.id) { session in
                            SessionRow(session: session) {
                                delete(session)
                            }

                            if session.id != sessions.prefix(previewLimit).last?.id {
                                Divider().opacity(0.5)
                            }
                        }
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
        .task(id: refreshID) {
            await refreshChallengeHints()
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionsDidChange)) { _ in
            challengeRefreshSeed &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .challengeSessionImpactDidChange)) { notification in
            guard let impact = notification.object as? ChallengeSessionImpact else { return }
            guard impact.bookID == book.id else { return }
            latestChallengeImpact = impact
            challengeRefreshSeed &+= 1
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
                        showingQuickLogSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                            Text("Session")
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
            iconCircleButton(systemName: "play.fill", tint: .green, accessibilityLabel: "Session starten") {
                let title = safeTitle(book)
                lastError = timer.start(
                    bookID: book.id,
                    bookTitle: title,
                    coverThumbnailData: book.userCoverData
                )
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

    @MainActor
    private func refreshChallengeHints() async {
        let now = Date()
        let active = challenges.filter { $0.periodStart <= now && $0.periodEnd > now }
        challengeProgressByID = await ChallengeRefreshCoordinator.computeProgressMap(
            for: active,
            modelContext: modelContext
        )
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
        let state = ReadingSessionLogging.BookState(book: book)

        let planResult = ReadingSessionLogging.plan(
            bookState: state,
            existingSessions: sessions,
            timing: timing,
            pages: pages,
            note: note
        )

        var session: ReadingSession? = nil
        var didMarkBookFinished = false

        switch planResult {
        case .failure(let err):
            lastError = err.message
            return
        case .success(let plan):
            plan.apply(to: book)
            session = plan.makeSession(book: book)
            didMarkBookFinished = plan.didMarkFinished
        }

        guard let session else {
            lastError = "Konnte Session nicht vorbereiten."
            return
        }

        modelContext.insert(session)

        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte Session nicht speichern: " + error.localizedDescription
        } else {
            lastError = nil
            Task { @MainActor in
                await ChallengeRefreshCoordinator.refreshAfterReadingSessionSave(
                    modelContext: modelContext,
                    bookID: book.id,
                    session: session,
                    didMarkBookFinished: didMarkBookFinished
                )
            }
        }
    }

    @MainActor
    private func delete(_ session: ReadingSession) {
        modelContext.delete(session)
        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte Session nicht löschen: " + error.localizedDescription
        } else {
            lastError = nil
            latestChallengeImpact = nil
            Task { @MainActor in
                await ChallengeRefreshCoordinator.refreshAfterReadingSessionMutation(modelContext: modelContext)
            }
        }
    }

    private func safeTitle(_ book: Book) -> String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Buch" : t
    }
}


private struct ChallengeActionHintRefreshID: Hashable {
    let challengeSignature: ChallengeSummarySignature
    let refreshSeed: Int
}
