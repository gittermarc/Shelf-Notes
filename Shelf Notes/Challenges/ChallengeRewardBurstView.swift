//
//  ChallengeRewardBurstView.swift
//  Shelf Notes
//
//  Small one-shot sparkle burst for completed challenge moments.
//

import SwiftUI

struct ChallengeRewardBurstView: View {
    let configuration: ChallengeCelebrationConfiguration
    var diameter: CGFloat = 132

    @State private var isExpanded = false

    private let particles: [ChallengeRewardParticle] = [
        ChallengeRewardParticle(symbol: "sparkle", angle: -92, distance: 46, size: 13),
        ChallengeRewardParticle(symbol: "sparkles", angle: -48, distance: 54, size: 15),
        ChallengeRewardParticle(symbol: "star.fill", angle: -12, distance: 45, size: 10),
        ChallengeRewardParticle(symbol: "sparkle", angle: 34, distance: 52, size: 12),
        ChallengeRewardParticle(symbol: "star.fill", angle: 78, distance: 48, size: 10),
        ChallengeRewardParticle(symbol: "sparkles", angle: 134, distance: 50, size: 14),
        ChallengeRewardParticle(symbol: "sparkle", angle: 178, distance: 43, size: 11),
        ChallengeRewardParticle(symbol: "star.fill", angle: 224, distance: 48, size: 9)
    ]

    var body: some View {
        ZStack {
            if configuration.allowsBurst {
                ForEach(particles) { particle in
                    Image(systemName: particle.symbol)
                        .font(.system(size: particle.size, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(isExpanded ? 0.0 : 0.95)
                        .scaleEffect(isExpanded ? 0.9 : 0.45)
                        .offset(offset(for: particle))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            guard configuration.allowsBurst else { return }
            isExpanded = false
            withAnimation(.easeOut(duration: 0.95)) {
                isExpanded = true
            }
        }
    }

    private func offset(for particle: ChallengeRewardParticle) -> CGSize {
        guard isExpanded else { return .zero }
        let radians = particle.angle * .pi / 180
        return CGSize(
            width: CGFloat(cos(radians)) * particle.distance,
            height: CGFloat(sin(radians)) * particle.distance
        )
    }
}

private struct ChallengeRewardParticle: Identifiable {
    let symbol: String
    let angle: Double
    let distance: CGFloat
    let size: CGFloat

    var id: String {
        "\(symbol)-\(angle)-\(distance)"
    }
}
