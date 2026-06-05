//
//  ChallengeAchievementsCard.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeAchievementsCard: View {
    let summary: ChallengeRewardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.highlightSystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.highlightTitle)
                        .font(.headline)

                    Text(summary.highlightText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                ChallengeAchievementPill(
                    title: "Erledigt",
                    value: "\(summary.completedCount)",
                    systemImage: "checkmark.seal"
                )

                ChallengeAchievementPill(
                    title: "Woche",
                    value: "\(summary.weeklyStreak)x",
                    systemImage: "flame"
                )

                ChallengeAchievementPill(
                    title: "Monat",
                    value: "\(summary.monthlyStreak)x",
                    systemImage: "calendar"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ChallengeAchievementPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
