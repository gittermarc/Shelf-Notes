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

    var body: some View {
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
                        save()
                    }
                    .disabled(book == nil)
                }
            }
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
        guard let book, let total = book.pageCount, total > 0 else { return nil }
        let already = book.readingSessionsSafe.compactMap { $0.pagesReadNormalized }.reduce(0, +)
        return max(0, total - already)
    }

    private func save() {
        guard let book else {
            lastError = "Buch nicht gefunden – kann nicht speichern."
            return
        }

        lastError = nil

        let pages = parsePositiveInt(pagesText)
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.isEmpty ? nil : note

        let effectiveEnd = pending.endedAt
        let effectiveStart = effectiveEnd.addingTimeInterval(-TimeInterval(max(0, pending.durationSeconds)))

        // ✅ Validate page input: you can't log more pages than the book has remaining.
        if let total = book.pageCount, total > 0, let p = pages {
            let already = book.readingSessionsSafe.compactMap { $0.pagesReadNormalized }.reduce(0, +)
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

        // Starting a session implies "reading" if the user hasn't started yet.
        if book.status == .toRead {
            book.status = .reading
        }

        // ✅ Auto-finish: if this session reaches the last page, mark the book as finished.
        if let total = book.pageCount, total > 0 {
            let already = book.readingSessionsSafe.compactMap { $0.pagesReadNormalized }.reduce(0, +)
            let after = already + (pages ?? 0)
            if after >= total {
                book.status = .finished

                if book.readFrom == nil {
                    let earliestExisting = book.readingSessionsSafe.map(\.startedAt).min()
                    let earliest = min(earliestExisting ?? effectiveStart, effectiveStart)
                    book.readFrom = earliest
                }

                book.readTo = effectiveEnd

                if let from = book.readFrom, let to = book.readTo, to < from {
                    book.readFrom = to
                }
            }
        }

        let session = ReadingSession(
            book: book,
            startAt: effectiveStart,
            durationSeconds: pending.durationSeconds,
            pagesRead: pages,
            note: trimmedNote
        )

        modelContext.insert(session)

        do {
            try modelContext.save()
            timer.discardPendingCompletion()
            dismiss()
        } catch {
            lastError = "Konnte Session nicht speichern: \(error.localizedDescription)"
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
