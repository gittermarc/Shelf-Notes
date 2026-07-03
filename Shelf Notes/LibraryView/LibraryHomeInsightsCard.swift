//
//  LibraryHomeInsightsCard.swift
//  Shelf Notes
//
//  Compact Smart Shelf card for lightweight progress, goal and challenge insights.
//

import SwiftUI

struct LibraryHomeInsightsCard: View {
    let snapshot: LibraryView.LibraryHomeInsightSnapshot

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 128), spacing: 8, alignment: .top)]
    }

    var body: some View {
        if snapshot.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("Dein Lesestand", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 0)

                    Text("kurz & ehrlich")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(snapshot.items) { item in
                        insightTile(item)
                    }
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
            .accessibilityLabel("Dein Lesestand")
        }
    }

    private func insightTile(_ item: LibraryView.LibraryHomeInsightItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: item.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isProminent ? Color.accentColor : Color.secondary)
                    .frame(width: 17)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(item.value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(item.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let progressFraction = item.progressFraction {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                    .accessibilityHidden(true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(item.isProminent ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
    }
}
