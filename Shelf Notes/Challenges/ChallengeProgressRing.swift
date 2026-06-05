//
//  ChallengeProgressRing.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 9
    var size: CGFloat = 72
    var centerText: String? = nil

    private var clampedFraction: Double {
        min(1, max(0, fraction))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: clampedFraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(centerText ?? percentText)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .padding(8)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Challenge Fortschritt \(percentText)")
    }

    private var percentText: String {
        "\(Int((clampedFraction * 100).rounded()))%"
    }
}
