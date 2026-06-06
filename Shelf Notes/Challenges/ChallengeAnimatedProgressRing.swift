//
//  ChallengeAnimatedProgressRing.swift
//  Shelf Notes
//
//  A motion-aware progress ring wrapper for challenge celebrations.
//

import SwiftUI

struct ChallengeAnimatedProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 9
    var size: CGFloat = 72
    var centerText: String? = nil
    var configuration: ChallengeCelebrationConfiguration = ChallengeCelebrationConfiguration()

    @State private var displayedFraction: Double = 0

    private var clampedFraction: Double {
        min(1, max(0, fraction))
    }

    var body: some View {
        ChallengeProgressRing(
            fraction: configuration.allowsProgressAnimation ? displayedFraction : clampedFraction,
            lineWidth: lineWidth,
            size: size,
            centerText: centerText
        )
        .onAppear {
            updateDisplayedFraction(animated: configuration.allowsProgressAnimation)
        }
        .onChange(of: clampedFraction) { _, _ in
            updateDisplayedFraction(animated: configuration.allowsProgressAnimation)
        }
        .onChange(of: configuration) { _, _ in
            updateDisplayedFraction(animated: configuration.allowsProgressAnimation)
        }
    }

    private func updateDisplayedFraction(animated: Bool) {
        guard animated else {
            displayedFraction = clampedFraction
            return
        }

        if displayedFraction == 0 && clampedFraction > 0 {
            displayedFraction = 0
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            displayedFraction = clampedFraction
        }
    }
}
