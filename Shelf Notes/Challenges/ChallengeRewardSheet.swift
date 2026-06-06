//
//  ChallengeRewardSheet.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeRewardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(ChallengePreferencesStorageKey.celebrationsEnabled) private var celebrationsEnabled: Bool = ChallengePreferencesStore.defaultCelebrationsEnabled
    @AppStorage(ChallengePreferencesStorageKey.hapticsEnabled) private var hapticsEnabled: Bool = ChallengePreferencesStore.defaultHapticsEnabled

    @State private var didPlayHaptic = false

    let item: ChallengeDashboardItem

    private var configuration: ChallengeCelebrationConfiguration {
        ChallengeCelebrationConfiguration(
            animationsEnabled: celebrationsEnabled,
            hapticsEnabled: hapticsEnabled,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            ChallengeCelebrationView(item: item, configuration: configuration)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))

                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("\(item.progressText) • \(item.kind.displayName) • \(item.difficultyText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(item.rewardText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
            } label: {
                Text("Sieg sichern")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            playHapticIfNeeded()
        }
    }

    private var title: String {
        switch item.kind {
        case .daily:
            return "Tagesmission geschafft"
        case .weekly:
            return "Wochenmission geschafft"
        case .monthly:
            return "Monatsmission geschafft"
        case .yearly:
            return "Jahresquest geschafft"
        case .unknown:
            return "Challenge eingesammelt"
        }
    }

    @MainActor
    private func playHapticIfNeeded() {
        guard !didPlayHaptic else { return }
        didPlayHaptic = true
        ChallengeHaptics.success(enabled: configuration.allowsHaptics)
    }
}
