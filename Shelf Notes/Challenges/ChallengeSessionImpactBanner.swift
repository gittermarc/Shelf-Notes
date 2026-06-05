//
//  ChallengeSessionImpactBanner.swift
//  Shelf Notes
//
//  Compact visual feedback after saving or previewing a reading session.
//

import SwiftUI

struct ChallengeSessionImpactBanner: View {
    let impact: ChallengeSessionImpact
    var showsEntries: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: impact.didCompleteChallenge ? "trophy.fill" : "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(impact.title)
                        .font(.subheadline.weight(.semibold))

                    Text(impact.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            if showsEntries {
                ForEach(impact.entries.prefix(2)) { entry in
                    HStack(spacing: 8) {
                        Label(entry.contributionText, systemImage: entry.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(entry.didComplete ? Color.accentColor : Color.secondary)

                        Spacer()

                        Text(entry.progressText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(impact.didCompleteChallenge ? 0.42 : 0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
