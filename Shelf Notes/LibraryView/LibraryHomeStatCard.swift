//
//  LibraryHomeStatCard.swift
//  Shelf Notes
//
//  Small stat card for the Smart Shelf dashboard.
//

import SwiftUI

struct LibraryHomeStatCard: View {
    let stat: LibraryView.LibraryHomeStat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: stat.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(stat.value)")
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()

                Text(stat.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title): \(stat.value)")
    }
}
