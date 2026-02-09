//
//  BulkAddToCollectionSheet.swift
//  Shelf Notes
//
//  Pick a collection to add multiple selected books.
//

import SwiftUI
import SwiftData

struct BulkAddToCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BookCollection.createdAt, order: .reverse) private var collections: [BookCollection]

    let selectionCount: Int
    let onSelect: (BookCollection) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if collections.isEmpty {
                        ContentUnavailableView(
                            "Keine Listen",
                            systemImage: "rectangle.stack",
                            description: Text("Erstelle zuerst eine Liste in „Listen“ – dann kannst du hier mehrere Bücher auf einmal hinzufügen.")
                        )
                    } else {
                        ForEach(collections) { col in
                            Button {
                                onSelect(col)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(col.name.isEmpty ? "Ohne Namen" : col.name)
                                        Text("\(col.booksSafe.count) Bücher")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !collections.isEmpty {
                    Section {
                        Text("Fügt \(selectionCount) ausgewählte Bücher zur Liste hinzu.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Zu Liste hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
