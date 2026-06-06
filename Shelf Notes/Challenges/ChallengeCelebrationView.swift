//
//  ChallengeCelebrationView.swift
//  Shelf Notes
//
//  Trophy moment used by the reward sheet.
//

import SwiftUI

struct ChallengeCelebrationView: View {
    let item: ChallengeDashboardItem
    let configuration: ChallengeCelebrationConfiguration

    @State private var appeared = false

    var body: some View {
        ZStack {
            ChallengeRewardBurstView(configuration: configuration, diameter: 150)

            ChallengeAnimatedProgressRing(
                fraction: 1,
                lineWidth: 8,
                size: 118,
                centerText: nil,
                configuration: configuration
            )
            .opacity(0.9)

            Circle()
                .fill(.regularMaterial)
                .frame(width: 92, height: 92)

            Image(systemName: item.kind == .yearly ? "crown.fill" : "trophy.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(configuration.allowsTrophyScale && appeared ? 1.08 : 1.0)
                .accessibilityHidden(true)
        }
        .frame(width: 156, height: 156)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Challenge-Belohnung für \(item.title)")
        .onAppear {
            guard configuration.allowsTrophyScale else {
                appeared = true
                return
            }

            appeared = false
            withAnimation(.spring(response: 0.48, dampingFraction: 0.58)) {
                appeared = true
            }
        }
    }
}
