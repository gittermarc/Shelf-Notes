//
//  SessionRow.swift
//  Shelf Notes
//
//  Split out of the former BookDetailSessionsViews.swift
//  (No functional changes)
//

import SwiftUI

struct SessionRow: View {
    let session: ReadingSession
    let onDelete: () -> Void

    private var presentation: ReadingSessionPresentation {
        ReadingSessionPresentationBuilder.make(session: session)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.primaryLine)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if presentation.metadataLine.isEmpty == false {
                    Text(presentation.metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let note = presentation.note {
                    Text(note)
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

}
