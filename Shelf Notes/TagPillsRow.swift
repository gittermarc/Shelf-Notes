//
//  TagPillsRow.swift
//  Shelf Notes
//
//  Lightweight, reusable tag pills for list rows.
//

import SwiftUI

/// A compact horizontal row of tag "pills".
///
/// Designed for use inside list rows (Library) where we want a single-line, scrollable presentation.
struct TagPillsRow: View {
    let tags: [String]
    var remainingCount: Int = 0
    var includeHashPrefix: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    pillText(includeHashPrefix ? "#\(tag)" : tag)
                }

                if remainingCount > 0 {
                    pillText("+\(remainingCount)")
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func pillText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

#Preview {
    List {
        TagPillsRow(tags: ["thriller", "nyc", "crime"], remainingCount: 2)
    }
}
