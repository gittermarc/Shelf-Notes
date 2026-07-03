//
//  LibraryShelfMaintenanceCard.swift
//  Shelf Notes
//
//  Smart Shelf card with tappable maintenance filter shortcuts.
//

import SwiftUI

struct LibraryShelfMaintenanceCard: View {
    let summary: LibraryView.LibraryShelfMaintenanceSummary
    let onSelectFilter: (LibraryView.LibrarySmartFilter) -> Void

    private var headline: String {
        let count = summary.totalCount
        if count == 1 {
            return "1 Regal-Hinweis"
        }
        return "\(count) Regal-Hinweise"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Regalpflege", systemImage: "wand.and.sparkles")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)

                Text(headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text("Finde Bücher, denen noch Cover, Tags, Seitenzahlen oder Bewertungen fehlen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(summary.items) { item in
                        Button {
                            onSelectFilter(item.smartFilter)
                        } label: {
                            maintenanceChip(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.count) \(item.title)")
                        .accessibilityHint("Filtert die Bibliothek")
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.secondary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func maintenanceChip(_ item: LibraryView.LibraryShelfMaintenanceItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .imageScale(.small)

            Text("\(item.count)")
                .monospacedDigit()
                .fontWeight(.semibold)

            Text(item.title)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.secondary.opacity(0.16), lineWidth: 1)
        }
        .contentShape(Capsule())
    }
}
