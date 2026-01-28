//
//  ChallengesSummaryCard.swift
//  Shelf Notes
//

import SwiftUI
import SwiftData

struct ChallengesSummaryCard: View {
    @Environment(\.modelContext) private var modelContext

    let challenges: [ChallengeRecord]

    @State private var weeklyProgress: ChallengeEngine.ChallengeProgress? = nil
    @State private var monthlyProgress: ChallengeEngine.ChallengeProgress? = nil

    var body: some View {
        let weekly = activeChallenge(kind: .weekly)
        let monthly = activeChallenge(kind: .monthly)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenges")
                    .font(.headline)

                Spacer()

                if let badge = unclaimedBadgeCount {
                    Text("\(badge)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(badge) unerledigte Belohnungen")
                }

                Image(systemName: "trophy")
                    .foregroundStyle(.secondary)
            }

            if let weekly {
                ChallengeMiniRow(kind: .weekly, challenge: weekly, progress: weeklyProgress)
            } else {
                Text("Wöchentliche Challenge wird vorbereitet …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let monthly {
                ChallengeMiniRow(kind: .monthly, challenge: monthly, progress: monthlyProgress)
            } else {
                Text("Monats-Challenge wird vorbereitet …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Tipp: Du kannst pro Challenge einmal pro Zeitraum neu würfeln.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task(id: challenges.count) {
            refreshProgress()
        }
    }

    private var unclaimedBadgeCount: Int? {
        let count = challenges.filter { $0.isActive && $0.isCompleted && !$0.isClaimed }.count
        return count > 0 ? count : nil
    }

    private func activeChallenge(kind: ChallengeKind) -> ChallengeRecord? {
        challenges.first(where: { $0.kind == kind && $0.isActive })
    }

    @MainActor
    private func refreshProgress() {
        ChallengeEngine.ensureCurrentChallenges(modelContext: modelContext)
        ChallengeEngine.refreshCompletionForActiveChallenges(modelContext: modelContext)

        if let weekly = activeChallenge(kind: .weekly) {
            weeklyProgress = ChallengeEngine.computeProgress(for: weekly, modelContext: modelContext)
        }

        if let monthly = activeChallenge(kind: .monthly) {
            monthlyProgress = ChallengeEngine.computeProgress(for: monthly, modelContext: modelContext)
        }
    }
}

private struct ChallengeMiniRow: View {
    let kind: ChallengeKind
    let challenge: ChallengeRecord
    let progress: ChallengeEngine.ChallengeProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: kind.badgeSystemImage)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(kind == .weekly ? "Diese Woche" : "Dieser Monat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(challenge.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                if challenge.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Erledigt")
                }
            }

            if let p = progress {
                ProgressView(value: p.fraction(target: challenge.targetValue))
                    .progressViewStyle(.linear)

                HStack {
                    Text(p.valueText(target: challenge.targetValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()

                    Text("bis \(deadlineLabel(for: challenge))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
    }

    private func deadlineLabel(for challenge: ChallengeRecord) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let lastDay = cal.date(byAdding: .day, value: -1, to: challenge.periodEnd) ?? challenge.periodEnd
        return lastDay.formatted(date: .abbreviated, time: .omitted)
    }
}
