//
//  ReadingSessionDynamicIslandView.swift
//  ShelfNotesLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

struct ReadingSessionDynamicIslandLeadingView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        ReadingSessionActivityCoverView(
            bookID: context.attributes.bookID,
            presentation: presentation,
            size: .dynamicIsland
        )
    }
}

struct ReadingSessionDynamicIslandCenterView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>
    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        let presentation = presentation

        VStack(alignment: .leading, spacing: 2) {
            Text(presentation.compactTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 5) {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "book.pages.fill")
                    .font(.caption2)

                Text(presentation.statusText)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)

                if let compactProgress = presentation.compactProgressText {
                    Text(compactProgress)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                } else if let source = presentation.sourceText {
                    Text(source)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReadingSessionDynamicIslandTrailingView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(presentation.timerCaption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if context.state.isPaused {
                Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            } else {
                Text(context.state.effectiveStartDate, style: .timer)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .accessibilityLabel(presentation.timerAccessibilityLabel)
    }
}

struct ReadingSessionDynamicIslandBottomView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>
    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        let presentation = presentation

        VStack(spacing: 5) {
            ReadingSessionActivityProgressView(presentation: presentation, mode: .dynamicIsland)

            HStack(spacing: 6) {
                ReadingSessionActivityChallengeChip(presentation: presentation, compact: true)

                Spacer(minLength: 2)

                ReadingSessionActivityControlsView(
                    context: context,
                    presentation: presentation,
                    mode: .dynamicIsland
                )
            }
        }
    }
}

struct ReadingSessionDynamicIslandCompactLeadingView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        if let fraction = presentation.progressFraction {
            ReadingSessionActivityMiniProgressIcon(
                fraction: fraction,
                systemImage: presentation.minimalSystemImage,
                accentHex: presentation.accentHex
            )
            .accessibilityLabel(presentation.progressAccessibilityLabel ?? presentation.statusText)
        } else {
            ReadingSessionActivityCoverView(
                bookID: context.attributes.bookID,
                presentation: presentation,
                size: .compact
            )
        }
    }
}

struct ReadingSessionDynamicIslandCompactTrailingView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        Group {
            if context.state.isPaused {
                Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
            } else {
                Text(context.state.effectiveStartDate, style: .timer)
            }
        }
        .font(.caption2.weight(.bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.70)
        .accessibilityLabel(presentation.timerAccessibilityLabel)
    }
}

struct ReadingSessionDynamicIslandMinimalView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        ReadingSessionActivityMiniProgressIcon(
            fraction: presentation.progressFraction,
            systemImage: presentation.minimalSystemImage,
            accentHex: presentation.accentHex
        )
        .accessibilityLabel(presentation.compactProgressText ?? presentation.compactStatusText)
    }
}

struct ReadingSessionActivityMiniProgressIcon: View {
    let fraction: Double?
    let systemImage: String
    let accentHex: String?

    private var accent: Color {
        ReadingSessionActivityTheme.accentColor(from: accentHex)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.28), lineWidth: 2)

            if let fraction {
                Circle()
                    .trim(from: 0, to: min(1, max(0, fraction)))
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
        }
        .frame(width: 24, height: 24)
    }
}
