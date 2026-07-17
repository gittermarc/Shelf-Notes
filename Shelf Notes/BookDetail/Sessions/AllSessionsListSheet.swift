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

    private var progressSessions: [ReadingSession] {
        ReadingAttemptSessionCoordinator.progressSessions(for: book, allSessions: sessions)
    }

    private var sessionGroups: [ReadingSessionGroup] {
        ReadingSessionGrouping.makeGroups(book: book, sessions: sessions)
    }

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
                    ReadingProgressView(book: book, sessions: progressSessions)
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
                    ForEach(sessionGroups) { group in
                        Section {
                            ForEach(group.sessions, id: \.id) { session in
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
                            .onDelete { offsets in
                                delete(Array(group.sessions), at: offsets)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                if let subtitle = group.subtitle {
                                    Text(subtitle)
                                }
                            }
                        } footer: {
                            if group.id == sessionGroups.last?.id {
                                Text("Wische eine Session nach links, um sie zu löschen.")
                            }
                        }
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

    @MainActor
    private func delete(_ source: [ReadingSession], at offsets: IndexSet) {
        let sessionsToDelete = offsets.map { source[$0] }
        switch ReadingSessionDeletionService.delete(
            sessions: sessionsToDelete,
            modelContext: modelContext
        ) {
        case .failure(let error):
            lastError = error.message
        case .success(let result):
            lastError = nil
            for snapshot in result.snapshots {
                ChallengeRefreshCoordinator.requestRefreshAfterReadingSessionDelete(
                    modelContext: modelContext,
                    sessionSnapshot: snapshot
                )
            }
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
