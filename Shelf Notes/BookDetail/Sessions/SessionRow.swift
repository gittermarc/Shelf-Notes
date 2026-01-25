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

    static let whenFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
