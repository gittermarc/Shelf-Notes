//
//  GroupedSessionPreviewView.swift
//  Shelf Notes
//

import SwiftUI

struct GroupedSessionPreviewView: View {
    let groups: [ReadingSessionGroup]
    let onDelete: (ReadingSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    SessionGroupHeaderView(group: group)

                    ForEach(group.sessions, id: \.id) { session in
                        SessionRow(session: session) {
                            onDelete(session)
                        }

                        if session.id != group.sessions.last?.id {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }
}

private struct SessionGroupHeaderView: View {
    let group: ReadingSessionGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if let subtitle = group.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
