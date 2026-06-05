//
//  ChallengeActionHintPanel.swift
//  Shelf Notes
//
//  Small session-adjacent hint panel for active challenges.
//

import SwiftUI

struct ChallengeActionHintPanel: View {
    let hints: [ChallengeActionHint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.badge.clock")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Zahlt auf Challenges ein")
                        .font(.subheadline.weight(.semibold))
                    Text("Diese Session kann direkt Fortschritt bringen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ForEach(hints) { hint in
                ChallengeActionHintRow(hint: hint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ChallengeActionHintRow: View {
    let hint: ChallengeActionHint

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hint.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(hint.kind.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(hint.progressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(hint.message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(hint.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            ChallengeProgressRing(
                fraction: hint.progressFraction,
                lineWidth: 5,
                size: 38,
                centerText: nil
            )
            .accessibilityHidden(true)
        }
    }
}
