//
//  BookDetailSessionsViews.swift
//  Shelf Notes
//
//  Extracted from BookDetailView.swift to keep it slimmer.
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
        DetailCard(title: "Lesesessions") {
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

        // Logging a session implies the user has started reading.
        if book.status == .toRead {
            book.status = .reading
        }

        let seconds = m * 60
        let end = Date()
        let start = end.addingTimeInterval(-TimeInterval(seconds))

        let normalizedPages: Int? = {
            guard let p = pages, p > 0 else { return nil }
            return p
        }()

        let trimmedNote: String? = {
            guard let n = note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
            return n
        }()

        let session = ReadingSession(
            book: book,
            startedAt: start,
            endedAt: end,
            pagesRead: normalizedPages,
            note: trimmedNote
        )

        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            lastError = "Konnte Session nicht speichern: \(error.localizedDescription)"
        }
    }

    private func delete(_ session: ReadingSession) {
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            lastError = "Konnte Session nicht löschen: \(error.localizedDescription)"
        }
    }

    private func safeTitle(_ book: Book) -> String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Buch" : t
    }
}

struct SessionRow: View {
    let session: ReadingSession
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLine)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if !secondaryLine.isEmpty {
                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 10)

            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Session Aktionen")
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var primaryLine: String {
        let when = Self.whenFormatter.string(from: session.startedAt)
        let minutes = max(1, Int(round(Double(max(0, session.durationSeconds)) / 60.0)))
        return "\(when) · \(minutes) Min."
    }

    private var secondaryLine: String {
        var parts: [String] = []
        if let p = session.pagesReadNormalized {
            parts.append("\(p) Seiten")
        }
        if let n = session.note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            parts.append(n)
        }
        return parts.joined(separator: " · ")
    }

    fileprivate static let whenFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}

struct QuickSessionLogSheet: View {
    let bookTitle: String
    let onCreate: (_ minutes: Int, _ pages: Int?, _ note: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int = 20
    @State private var pagesText: String = ""
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $minutes, in: 1...600, step: 5) {
                        HStack {
                            Text("Dauer")
                            Spacer()
                            Text("\(minutes) Min.")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Quick-Log")
                } footer: {
                    Text("Hier wird eine Session als „jetzt minus Dauer“ bis „jetzt“ gespeichert.")
                }

                Section("Optional") {
                    TextField("Seiten gelesen", text: $pagesText)
                        .keyboardType(.numberPad)
                }

                Section("Notiz") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle(bookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let pages = parsePositiveInt(pagesText)
                        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(minutes, pages, note.isEmpty ? nil : note)
                        dismiss()
                    }
                    .disabled(minutes <= 0)
                }
            }
        }
    }

    private func parsePositiveInt(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let val = Int(trimmed), val > 0 else { return nil }
        return val
    }
}

struct AllSessionsListSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @Query private var sessions: [ReadingSession]

    @State private var lastError: String? = nil

    init(book: Book) {
        self.book = book
        let bookID = book.id
        _sessions = Query(
            filter: #Predicate<ReadingSession> { $0.book?.id == bookID },
            sort: [SortDescriptor(\ReadingSession.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ReadingProgressView(book: book, sessions: sessions)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                if let err = lastError {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if sessions.isEmpty {
                    Section {
                        Text("Noch keine Sessions für dieses Buch.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(sessions, id: \.id) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(primaryLine(for: session))
                                    .font(.subheadline.weight(.semibold))

                                let secondary = secondaryLine(for: session)
                                if !secondary.isEmpty {
                                    Text(secondary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    } header: {
                        Text("Neueste zuerst")
                    } footer: {
                        Text("Wische eine Session nach links, um sie zu löschen.")
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            let s = sessions[idx]
            modelContext.delete(s)
        }
        do {
            try modelContext.save()
            lastError = nil
        } catch {
            lastError = "Konnte nicht löschen: \(error.localizedDescription)"
        }
    }

    private func primaryLine(for session: ReadingSession) -> String {
        let when = SessionRow.whenFormatter.string(from: session.startedAt)
        let minutes = max(1, Int(round(Double(max(0, session.durationSeconds)) / 60.0)))
        return "\(when) · \(minutes) Min."
    }

    private func secondaryLine(for session: ReadingSession) -> String {
        var parts: [String] = []
        if let p = session.pagesReadNormalized {
            parts.append("\(p) Seiten")
        }
        if let n = session.note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            parts.append(n)
        }
        return parts.joined(separator: " · ")
    }
}
// MARK: - Shared card styling (local copy)
//
// BookDetailView.swift had its own file-private DetailCard. Since this file is separate,
// we keep the exact same styling here to avoid any UI regressions.

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}


// MARK: - Reading progress UI

struct ReadingProgressView: View {
    @Environment(\.modelContext) private var modelContext

    let book: Book
    let sessions: [ReadingSession]

    @State private var showingPageCountPrompt: Bool = false
    @State private var pageCountText: String = ""
    @State private var inlineError: String? = nil

    private var totalPages: Int? {
        guard let t = book.pageCount, t > 0 else { return nil }
        return t
    }

    private var pagesRead: Int {
        sessions
            .compactMap { $0.pagesReadNormalized }
            .reduce(0, +)
    }

    private var isFinished: Bool {
        book.status == .finished
    }

    /// Returns nil when we can't compute progress (no pageCount) and the book isn't finished.
    private var progressFraction: Double? {
        if isFinished { return 1.0 }
        guard let totalPages else { return nil }
        return min(1.0, max(0.0, Double(pagesRead) / Double(totalPages)))
    }

    private var percentText: String {
        if isFinished { return "100%" }
        guard let fraction = progressFraction else { return "—" }
        let pct = Int((fraction * 100.0).rounded())
        return "\(pct)%"
    }

    private var detailLine: String {
        if isFinished {
            if let totalPages {
                return "Gelesen · \(totalPages) Seiten"
            } else {
                return "Als gelesen markiert"
            }
        }

        if let totalPages {
            let clampedRead = min(max(0, pagesRead), totalPages)
            let remaining = max(0, totalPages - clampedRead)
            return "\(clampedRead)/\(totalPages) Seiten · Noch \(remaining)"
        }

        // No pageCount
        if pagesRead > 0 {
            return "\(pagesRead) Seiten geloggt · Gesamtseiten unbekannt"
        }
        return "Gesamtseiten unbekannt"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Fortschritt")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                // ✏️ Seitenzahl nachtragen, wenn unbekannt
                if totalPages == nil {
                    Button {
                        inlineError = nil
                        pageCountText = ""
                        showingPageCountPrompt = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Seitenzahl nachtragen")
                }

                Text(percentText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let progressFraction {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
            } else {
                // Unknown total pages → keep the UI stable.
                ProgressView(value: 0)
                    .progressViewStyle(.linear)
                    .opacity(0.35)
            }

            Text(detailLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let err = inlineError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fortschritt")
        .accessibilityValue(percentText)
        .alert("Seitenzahl nachtragen", isPresented: $showingPageCountPrompt) {
            TextField("z.B. 384", text: $pageCountText)
                .keyboardType(.numberPad)

            Button("Speichern") {
                savePageCount()
            }

            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Ohne Gesamtseiten kann die App den Fortschritt nicht korrekt berechnen.")
        }
    }

    private func savePageCount() {
        inlineError = nil

        let trimmed = pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Int(trimmed), val > 0 else {
            inlineError = "Bitte eine gültige Seitenzahl (> 0) eingeben."
            return
        }

        book.pageCount = val

        do {
            try modelContext.save()
        } catch {
            inlineError = "Konnte Seitenzahl nicht speichern: \(error.localizedDescription)"
        }
    }
}
