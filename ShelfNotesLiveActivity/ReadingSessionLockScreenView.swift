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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(ReadingSessionActivityTheme.cardBackground(accentHex: presentation.accentHex))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(ReadingSessionActivityTheme.accentColor(from: presentation.accentHex).opacity(0.18))
                        .frame(width: 118, height: 118)
                        .blur(radius: 18)
                        .offset(x: 34, y: -38)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }

            HStack(alignment: .top, spacing: 14) {
                ReadingSessionActivityCoverView(
                    bookID: context.attributes.bookID,
                    presentation: presentation,
                    size: .lockScreen
                )

                VStack(alignment: .leading, spacing: 10) {
                    ReadingSessionStatusHeader(presentation: presentation)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        if let author = presentation.authorText {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }

                    ReadingSessionTimerBlock(context: context, presentation: presentation)

                    ReadingSessionActivityProgressView(presentation: presentation, mode: .lockScreen)
                        .tint(.white)

                    if presentation.hasChallenge {
                        HStack(alignment: .center, spacing: 8) {
                            ReadingSessionActivityChallengeChip(presentation: presentation, compact: false)

                            Spacer(minLength: 6)
                        }
                    }

                    ReadingSessionActivityControlsView(
                        context: context,
                        presentation: presentation,
                        mode: .lockScreen
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private struct ReadingSessionStatusHeader: View {
    let presentation: ReadingSessionLiveActivityPresentation

    private var accent: Color {
        ReadingSessionActivityTheme.accentColor(from: presentation.accentHex)
    }

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)

                Text(presentation.statusText)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white.opacity(0.12), in: Capsule())
            .foregroundStyle(.white)
            .accessibilityLabel("Status: \(presentation.statusText)")

            if let attempt = presentation.attemptText {
                Text(attempt)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.18), in: Capsule())
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct ReadingSessionTimerBlock: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>
    let presentation: ReadingSessionLiveActivityPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(presentation.timerCaption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .textCase(.uppercase)
                .tracking(0.5)

            if context.state.isPaused {
                Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel(presentation.timerAccessibilityLabel)
            } else {
                Text(context.state.effectiveStartDate, style: .timer)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel(presentation.timerAccessibilityLabel)
            }
        }
    }
}
