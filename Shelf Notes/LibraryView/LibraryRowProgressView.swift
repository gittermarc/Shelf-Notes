//
//  LibraryRowProgressView.swift
//  Shelf Notes
//
//  Compact reading progress cue for library list rows and grid cards.
//

import SwiftUI

struct LibraryRowProgressView: View {
    enum Style {
        case list
        case grid
    }

    let presentation: LibraryBookPresentation
    let style: Style

    init(
        presentation: LibraryBookPresentation,
        style: Style = .list
    ) {
        self.presentation = presentation
        self.style = style
    }

    var body: some View {
        if presentation.shouldShowReadingProgress,
           let fraction = presentation.progressFraction {
            switch style {
            case .list:
                listProgress(fraction: fraction)
            case .grid:
                gridProgress(fraction: fraction)
            }
        }
    }

    private func listProgress(fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)

            HStack(spacing: 6) {
                if let progressText = presentation.progressText {
                    Text(progressText)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                if let pageProgressText = presentation.pageProgressText {
                    Text(pageProgressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let remainingPagesText = presentation.remainingPagesText {
                    Text(remainingPagesText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let rereadBadgeText = presentation.rereadBadgeText {
                    Text(rereadBadgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilitySummary)
    }

    private func gridProgress(fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)

            HStack(spacing: 4) {
                if let progressText = presentation.progressText {
                    Text(progressText)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }

                if let rereadBadgeText = presentation.rereadBadgeText {
                    Text(rereadBadgeText)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilitySummary)
    }
}
