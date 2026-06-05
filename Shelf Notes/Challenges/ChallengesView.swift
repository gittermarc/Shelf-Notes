//
//  ChallengesView.swift
//  Shelf Notes
//
//  Motivation board for weekly and monthly reading challenges.
//

import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)])
    private var allChallenges: [ChallengeRecord]

    @State private var progressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]
    @State private var rewardItem: ChallengeDashboardItem?

    var body: some View {
        let dashboard = ChallengeDashboardBuilder.make(
            challenges: allChallenges,
            progressByID: progressByID
        )
        let signature = ChallengeSummarySignature(challenges: allChallenges)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ChallengeHeroCard(
                    hero: dashboard.hero,
                    completedCount: dashboard.completedCount,
                    unclaimedCount: dashboard.unclaimedCount
                )

                if dashboard.activeItems.isEmpty {
                    ChallengeBoardEmptyState()
                } else {
                    activeChallengesSection(items: dashboard.activeItems)
                }

                if !dashboard.historyItems.isEmpty {
                    ChallengeHistorySection(items: dashboard.historyItems, onClaim: claim)
                }

                challengeInfoCard
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: signature) {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .sheet(item: $rewardItem) { item in
            ChallengeRewardSheet(item: item)
        }
    }

    private func activeChallengesSection(items: [ChallengeDashboardItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktive Missionen")
                        .font(.headline)
                    Text("Woche und Monat auf einen Blick")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            LazyVGrid(columns: activeColumns, spacing: 12) {
                ForEach(items) { item in
                    ChallengeActiveCard(
                        item: item,
                        onClaim: claim,
                        onReroll: reroll
                    )
                }
            }
        }
    }

    private var activeColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 310, maximum: 520), spacing: 12, alignment: .top)]
    }

    private var challengeInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Wie das funktioniert")
                    .font(.headline)
            }

            Text("Shelf Notes erzeugt automatisch eine Wochen- und Monats-Challenge. Ziele orientieren sich grob an deinem bisherigen Leseverhalten. Fortschritt kommt aus Lesesessions, Seitenangaben und abgeschlossenen Büchern.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pro Zeitraum kannst du einmal eine Alternative wählen. Das bleibt bewusst begrenzt, damit die Mission nicht beliebig wird.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
    }

    @MainActor
    private func refresh() async {
        await ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(modelContext: modelContext)

        let interesting = interestingChallenges()
        let newMap = await ChallengeEngine.computeProgressMap(for: interesting, modelContext: modelContext)
        progressByID = newMap
    }

    @MainActor
    private func claim(_ item: ChallengeDashboardItem) {
        guard let challenge = allChallenges.first(where: { $0.id == item.id }) else { return }
        ChallengeEngine.claim(challenge, modelContext: modelContext)
        rewardItem = item
        Task { await refresh() }
    }

    @MainActor
    private func reroll(_ item: ChallengeDashboardItem) {
        guard let challenge = allChallenges.first(where: { $0.id == item.id }) else { return }
        ChallengeEngine.reroll(challenge, modelContext: modelContext)
        Task { await refresh() }
    }

    private func interestingChallenges() -> [ChallengeRecord] {
        let now = Date()
        let active = allChallenges
            .filter { $0.periodStart <= now && $0.periodEnd > now }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind == .weekly }
                return lhs.periodStart < rhs.periodStart
            }

        let history = allChallenges
            .filter { $0.periodEnd <= now }
            .sorted { lhs, rhs in
                if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd > rhs.periodEnd }
                return lhs.kind == .weekly
            }
            .prefix(12)

        return active + history
    }
}

private struct ChallengeBoardEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Missionen werden vorbereitet")
                .font(.headline)

            Text("Sobald die aktuelle Woche und der aktuelle Monat angelegt sind, erscheinen hier deine aktiven Challenges mit Fortschritt und nächstem Ziel.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
    }
}
