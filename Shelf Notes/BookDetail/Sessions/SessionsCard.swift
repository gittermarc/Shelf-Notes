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

    @Query private var sessions: [ReadingSession]

    private let previewLimit: Int = 8

    /// Remaining pages until the book is finished (based on logged sessions).
    /// Returns nil when the book has no valid total page count.
    private var remainingPagesForBook: Int? {
        guard let total = book.pageCount, total > 0 else { return nil }
        let already = sessions.compactMap { $0.pagesReadNormalized }.reduce(0, +)
        return max(0, total - already)
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
        BookDetailCard(title: "Lesesessions") {
            VStack(alignment: .leading, spacing: 12) {
                header

                ReadingProgressView(book: book, sessions: sessions)

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
                lastError = timer.start(bookID: book.id, bookTitle: title)
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

    private func addSession(minutes: Int, pages: Int?, note: String?) {
        lastError = nil

        let m = max(0, minutes)
        guard m > 0 else {
            lastError = "Bitte eine Dauer > 0 Minuten eingeben."
            return
        }

        let seconds = m * 60
        let end = Date()
        let start = end.addingTimeInterval(-TimeInterval(seconds))

        let normalizedPages: Int? = {
            guard let p = pages, p > 0 else { return nil }
            return p
        }()

        // ✅ Validate page input: you can't log more pages than the book has remaining.
        if let total = book.pageCount, total > 0, let p = normalizedPages {
            let already = sessions.compactMap { $0.pagesReadNormalized }.reduce(0, +)
            let remaining = max(0, total - already)

            if remaining <= 0 {
                lastError = "Dieses Buch hat bereits alle \(total) Seiten erreicht – du kannst keine weiteren Seiten loggen."
                return
            }

            if p > remaining {
                lastError = "Zu viele Seiten: Es sind nur noch \(remaining) von \(total) Seiten übrig."
                return
            }
        }

        let trimmedNote: String? = {
            guard let n = note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
            return n
        }()

        // Logging a session implies the user has started reading.
        if book.status == .toRead {
            book.status = .reading
        }

        // ✅ Auto-finish: if this session reaches the last page, mark the book as finished.
        if let total = book.pageCount, total > 0 {
            let already = sessions.compactMap { $0.pagesReadNormalized }.reduce(0, +)
            let after = already + (normalizedPages ?? 0)
            if after >= total {
                book.status = .finished

                if book.readFrom == nil {
                    let earliestExisting = sessions.map(\.startedAt).min()
                    let earliest = min(earliestExisting ?? start, start)
                    book.readFrom = earliest
                }
                book.readTo = end

                if let from = book.readFrom, let to = book.readTo, to < from {
                    book.readFrom = to
                }
            }
        }

        let session = ReadingSession(
            book: book,
            startedAt: start,
            endedAt: end,
            pagesRead: normalizedPages,
            note: trimmedNote
        )

        modelContext.insert(session)

        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte Session nicht speichern: " + error.localizedDescription
        } else {
            lastError = nil
        }
    }

    private func delete(_ session: ReadingSession) {
        modelContext.delete(session)
        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte Session nicht löschen: " + error.localizedDescription
        } else {
            lastError = nil
        }
    }

    private func safeTitle(_ book: Book) -> String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Buch" : t
    }
}
