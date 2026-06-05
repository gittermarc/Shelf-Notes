//
//  ChallengeRewardSheet.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeRewardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: ChallengeDashboardItem

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 96, height: 96)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 8) {
                Text("Challenge eingesammelt")
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
                Text("Weiter geht's")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
