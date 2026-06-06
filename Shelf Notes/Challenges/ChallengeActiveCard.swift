//
//  ChallengeActiveCard.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeActiveCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ChallengePreferencesStorageKey.celebrationsEnabled) private var celebrationsEnabled: Bool = ChallengePreferencesStore.defaultCelebrationsEnabled

    let item: ChallengeDashboardItem
    let onClaim: (ChallengeDashboardItem) -> Void
    let onReroll: (ChallengeDashboardItem) -> Void

    private var celebrationConfiguration: ChallengeCelebrationConfiguration {
        ChallengeCelebrationConfiguration(
            animationsEnabled: celebrationsEnabled,
            hapticsEnabled: false,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 16) {
                ChallengeAnimatedProgressRing(
                    fraction: item.progressFraction,
                    size: 78,
                    configuration: celebrationConfiguration
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.progressText)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()

                    Text(item.remainingText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.isRewardReady ? Color.accentColor : Color.secondary)

                    Text(item.motivationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().opacity(0.65)

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(item.isRewardReady ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .shadow(
            color: Color.accentColor.opacity(item.shouldHighlightCompletion ? 0.16 : 0),
            radius: item.shouldHighlightCompletion ? 16 : 0,
            x: 0,
            y: item.shouldHighlightCompletion ? 8 : 0
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.metric.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                metadataPills
            }

            Spacer(minLength: 8)

            Label(item.statusText, systemImage: statusSystemImage)
                .font(.caption.weight(.semibold))
                .labelStyle(.iconOnly)
                .foregroundStyle(item.isRewardReady ? Color.accentColor : Color.secondary)
                .accessibilityLabel(item.statusText)
        }
    }

    private var statusSystemImage: String {
        item.celebrationState.isHighlighted ? item.celebrationState.systemImage : item.statusSystemImage
    }

    private var metadataPills: some View {
        HStack(spacing: 6) {
            ChallengeCadencePill(kind: item.kind)

            Text(item.difficultyText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.10))
                .clipShape(Capsule())

            Text(item.periodLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.displayName), \(item.difficultyText), Zeitraum \(item.periodLabel)")
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.timeRemainingText)
                    .font(.caption.weight(.semibold))
                Text(item.deadlineText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isRewardReady {
                Button {
                    onClaim(item)
                } label: {
                    Label("Abholen", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
            } else if item.canReroll {
                Button {
                    onReroll(item)
                } label: {
                    Label("Alternative", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Wählt einmalig eine andere Challenge für diesen Zeitraum")
            }
        }
    }
}
