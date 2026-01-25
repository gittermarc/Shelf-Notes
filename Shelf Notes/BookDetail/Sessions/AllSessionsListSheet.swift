//
//  AllSessionsListSheet.swift
//  Shelf Notes
//
//  Split out of the former BookDetailSessionsViews.swift
//  (No functional changes)
//

import SwiftUI
import SwiftData

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
        if let error = modelContext.saveWithDiagnostics() {
            lastError = "Konnte nicht löschen: " + error.localizedDescription
        } else {
            lastError = nil
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
