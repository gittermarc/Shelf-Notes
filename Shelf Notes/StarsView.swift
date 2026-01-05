//
//  StarsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 05.01.26.
//

import SwiftUI

/// Zeigt eine 0...5 Sterne-Bewertung (inkl. halber Sterne).
struct StarsView: View {
    let rating: Double
    var maxStars: Int = 5
    var size: CGFloat = 12

    var body: some View {
        let clamped = min(max(rating, 0), Double(maxStars))

        HStack(spacing: 2) {
            ForEach(1...maxStars, id: \.self) { index in
                Image(systemName: symbolName(for: clamped, index: index))
                    .font(.system(size: size))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(Text("Bewertung"))
        .accessibilityValue(Text(String(format: "%.1f von %d", clamped, maxStars)))
    }

    private func symbolName(for rating: Double, index: Int) -> String {
        let threshold = Double(index)

        if rating >= threshold {
            return "star.fill"
        } else if rating >= threshold - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}
