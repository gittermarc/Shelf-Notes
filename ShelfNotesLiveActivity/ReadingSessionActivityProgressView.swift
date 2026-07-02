//
//  ReadingSessionActivityProgressView.swift
//  ShelfNotesLiveActivity
//

import SwiftUI

enum ReadingSessionActivityProgressMode: Equatable {
    case lockScreen
    case dynamicIsland
}

struct ReadingSessionActivityProgressView: View {
    let presentation: ReadingSessionLiveActivityPresentation
    let mode: ReadingSessionActivityProgressMode

    private var accent: Color {
        ReadingSessionActivityTheme.accentColor(from: presentation.accentHex)
    }

    private var primaryText: Color {
        mode == .lockScreen ? .white : .primary
    }

    private var secondaryText: Color {
        mode == .lockScreen ? .white.opacity(0.70) : .secondary
    }

    var body: some View {
        if presentation.hasProgress {
            VStack(alignment: .leading, spacing: mode == .lockScreen ? 4 : 3) {
                HStack(spacing: 8) {
                    if let progressText = presentation.progressText {
                        Text(progressText)
                            .font(mode == .lockScreen ? .caption2.weight(.semibold) : .caption2.weight(.semibold))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    if let detail = presentation.remainingPagesText ?? presentation.progressDetailText {
                        Text(detail)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                }

                if let fraction = presentation.progressFraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(accent)
                        .frame(height: mode == .lockScreen ? 4 : 3)
                        .clipShape(Capsule())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.progressAccessibilityLabel ?? "Lesefortschritt")
        }
    }
}

struct ReadingSessionActivityChallengeChip: View {
    let presentation: ReadingSessionLiveActivityPresentation
    let compact: Bool

    private var accent: Color {
        ReadingSessionActivityTheme.accentColor(from: presentation.accentHex)
    }

    private var detailText: Color {
        compact ? .secondary : .white.opacity(0.72)
    }

    var body: some View {
        if presentation.hasChallenge {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.bold))

                VStack(alignment: .leading, spacing: compact ? 0 : 1) {
                    if let title = presentation.challengeTitle {
                        Text(title)
                            .font(compact ? .caption2.weight(.semibold) : .caption2.weight(.semibold))
                            .lineLimit(1)
                    }

                    if !compact, let detail = presentation.challengeDetail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(detailText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 3 : 5)
            .background(accent.opacity(0.16), in: Capsule())
            .foregroundStyle(accent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.challengeAccessibilityLabel ?? "Motivation")
        }
    }
}
