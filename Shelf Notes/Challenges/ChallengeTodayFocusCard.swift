//
//  ChallengeTodayFocusCard.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeTodayFocusCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ChallengePreferencesStorageKey.celebrationsEnabled) private var celebrationsEnabled: Bool = ChallengePreferencesStore.defaultCelebrationsEnabled

    let focus: ChallengeDashboardTodayFocus
    let onClaim: (ChallengeDashboardItem) -> Void
    let onReroll: (ChallengeDashboardItem) -> Void

    private var item: ChallengeDashboardItem { focus.item }

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

            HStack(alignment: .center, spacing: 16) {
                ChallengeAnimatedProgressRing(
                    fraction: item.progressFraction,
                    lineWidth: 10,
                    size: 92,
                    configuration: celebrationConfiguration
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(focus.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(item.progressText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()

                        Text(item.remainingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.accentColor.opacity(0.34), lineWidth: 1)
        }
        .shadow(
            color: Color.accentColor.opacity(item.isRewardReady ? 0.16 : 0),
            radius: item.isRewardReady ? 18 : 0,
            x: 0,
            y: item.isRewardReady ? 8 : 0
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ChallengeCadencePill(kind: item.kind, label: focus.headline, isProminent: true)

            Text(focus.footnote)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Image(systemName: item.metric.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            Label(focus.actionText, systemImage: "arrow.forward.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

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
                .accessibilityHint("Wählt einmalig eine andere Tagesmission")
            }
        }
    }

    private var accessibilityLabel: String {
        "Heute im Fokus: \(item.title), \(item.progressText), \(item.remainingText)"
    }
}
