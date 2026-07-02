//
//  ReadingSessionLockScreenView.swift
//  ShelfNotesLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

struct ReadingSessionLockScreenView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    private var presentation: ReadingSessionLiveActivityPresentation {
        ReadingSessionLiveActivityPresentation(attributes: context.attributes, state: context.state)
    }

    var body: some View {
        let presentation = presentation

        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ReadingSessionActivityTheme.cardBackground(accentHex: presentation.accentHex))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(ReadingSessionActivityTheme.accentColor(from: presentation.accentHex).opacity(0.16))
                        .frame(width: 96, height: 96)
                        .blur(radius: 16)
                        .offset(x: 26, y: -32)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }

            HStack(alignment: .top, spacing: 10) {
                ReadingSessionActivityCoverView(
                    bookID: context.attributes.bookID,
                    presentation: presentation,
                    size: .lockScreen
                )
                .layoutPriority(1)

                VStack(alignment: .leading, spacing: 6) {
                    ReadingSessionStatusHeader(presentation: presentation)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(presentation.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)

                        if let author = presentation.authorText {
                            Text(author)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.70))
                                .lineLimit(1)
                                .minimumScaleFactor(0.80)
                        }
                    }

                    ReadingSessionTimerBlock(context: context, presentation: presentation)

                    ReadingSessionActivityProgressView(presentation: presentation, mode: .lockScreen)
                        .tint(.white)

                    HStack(alignment: .center, spacing: 6) {
                        if presentation.hasChallenge {
                            ReadingSessionActivityChallengeChip(presentation: presentation, compact: true)
                                .layoutPriority(1)
                        }

                        Spacer(minLength: 2)

                        ReadingSessionActivityControlsView(
                            context: context,
                            presentation: presentation,
                            mode: .lockScreen
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ReadingSessionStatusHeader: View {
    let presentation: ReadingSessionLiveActivityPresentation

    private var accent: Color {
        ReadingSessionActivityTheme.accentColor(from: presentation.accentHex)
    }

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 4) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text(presentation.statusText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.25)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
            .foregroundStyle(.white)
            .accessibilityLabel("Status: \(presentation.statusText)")

            if let attempt = presentation.attemptText {
                Text(attempt)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.18), in: Capsule())
                    .foregroundStyle(accent)
                    .accessibilityLabel("Lesedurchgang: \(attempt)")
            }
        }
    }
}

private struct ReadingSessionTimerBlock: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>
    let presentation: ReadingSessionLiveActivityPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(presentation.timerCaption)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .textCase(.uppercase)
                .tracking(0.45)
                .lineLimit(1)

            if context.state.isPaused {
                Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel(presentation.timerAccessibilityLabel)
            } else {
                Text(context.state.effectiveStartDate, style: .timer)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel(presentation.timerAccessibilityLabel)
            }
        }
    }
}
