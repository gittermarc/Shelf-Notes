//
//  ReadingTimelineYearSectionView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 25.01.26.
//

import SwiftUI
import SwiftData

// MARK: - Position tracking (for Mini-Map auto highlight)

struct ReadingTimelineYearMarkerPositionReporter: View {
    let year: Int
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ReadingTimelineYearMarkerMidXPreferenceKey.self,
                    value: [year: proxy.frame(in: .named(coordinateSpaceName)).midX]
                )
        }
    }
}

struct ReadingTimelineYearMarkerMidXPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        // Merge dictionaries; newest wins.
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Year section UI

/// A year “marker” on the timeline: summary card + line + dot.
struct ReadingTimelineYearSectionView: View {
    let year: Int
    let stats: ReadingTimelineYearStats
    let cardWidth: CGFloat
    let previewCoverSize: CGSize
    let coordinateSpaceName: String

    var body: some View {
        VStack(spacing: 10) {
            ReadingTimelineYearSummaryCard(
                year: year,
                stats: stats,
                previewCoverSize: previewCoverSize
            )

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2, height: 18)

            ReadingTimelineDot()
        }
        .padding(.bottom, 2)
        .frame(width: cardWidth)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.97)
                .opacity(phase.isIdentity ? 1.0 : 0.9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Jahr \(year), \(stats.count) Bücher")
        // Report marker positions so the mini-map can highlight the year closest to the viewport center.
        .background(ReadingTimelineYearMarkerPositionReporter(year: year, coordinateSpaceName: coordinateSpaceName))
    }
}

private struct ReadingTimelineYearSummaryCard: View {
    let year: Int
    let stats: ReadingTimelineYearStats
    let previewCoverSize: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()

                Spacer()

                Text("\(stats.count) \(stats.count == 1 ? "Buch" : "Bücher")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let avg = stats.averageRatingText {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text("Ø \(avg)")
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "star")
                        Text("Noch kein Ø-Rating")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if stats.ratedCount > 0, stats.ratedCount < stats.count {
                    Text("(\(stats.ratedCount) bewertet)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()
            }

            if let range = stats.dateRangeText {
                Text(range)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !stats.previewBooks.isEmpty {
                HStack(spacing: -10) {
                    ForEach(Array(stats.previewBooks.prefix(4).enumerated()), id: \.offset) { _, b in
                        BookCoverThumbnailView(
                            book: b,
                            size: previewCoverSize,
                            cornerRadius: 10,
                            contentMode: .fill
                        )
                        .shadow(radius: 6, y: 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.background.opacity(0.9), lineWidth: 2)
                        }
                        .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}
