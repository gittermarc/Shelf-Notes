//
//  ChallengesView.swift
//  Shelf Notes
//
//  Motivation board for reading challenges.
//

import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)])
    private var allChallenges: [ChallengeRecord]

    @AppStorage(ChallengePreferencesStorageKey.enabledKinds) private var enabledKindsRaw: String = ChallengePreferencesStore.defaultEnabledKindsRaw
    @AppStorage(ChallengePreferencesStorageKey.preset) private var presetRaw: String = ChallengePreferencesStore.defaultPresetRaw

    @State private var progressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]
    @State private var rewardItem: ChallengeDashboardItem?

    private var challengePreferences: ChallengePreferences {
        ChallengePreferencesStore.preferences(enabledKindsRaw: enabledKindsRaw, presetRaw: presetRaw)
    }

    var body: some View {
        let preferences = challengePreferences
        let dashboard = ChallengeDashboardBuilder.make(
            challenges: allChallenges,
            progressByID: progressByID,
            enabledKinds: preferences.enabledKinds
        )
        let signature = ChallengeSummarySignature(challenges: allChallenges)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ChallengeHeroCard(
                    hero: dashboard.hero,
                    completedCount: dashboard.completedCount,
                    unclaimedCount: dashboard.unclaimedCount
                )

                ChallengeAchievementsCard(summary: dashboard.rewardSummary)

                if dashboard.activeItems.isEmpty {
                    ChallengeBoardEmptyState(isPaused: preferences.enabledKinds.isEmpty)
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
        .task(id: challengePreferences.storageSignature) {
            await refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionsDidChange)) { _ in
            Task { await refresh(ensuringCurrent: false) }
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
                    Text("Deine aktuellen Lese-Missionen auf einen Blick")
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

            Text("Shelf Notes erzeugt automatisch die aktuell aktivierten Challenge-Zeiträume. Eine Template-Auswahl variiert die Missionen anhand deines bisherigen Leseverhaltens, ohne dafür neue CloudKit-Felder zu brauchen.")
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
    private func refresh(ensuringCurrent: Bool = true) async {
        let preferences = challengePreferences
        if ensuringCurrent {
            await ChallengeRefreshCoordinator.prepareCurrentChallenges(
                modelContext: modelContext,
                enabledKinds: preferences.enabledKinds
            )
        }

        let interesting = interestingChallenges(enabledKinds: preferences.enabledKinds)
        let newMap = await ChallengeRefreshCoordinator.computeProgressMap(for: interesting, modelContext: modelContext)
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

    @MainActor
    private func interestingChallenges(enabledKinds: [ChallengeKind]) -> [ChallengeRecord] {
        let now = Date()
        let enabledKindSet = Set(ChallengePreferences.normalizedKinds(enabledKinds))
        let active = allChallenges
            .filter { record in
                record.periodStart <= now && record.periodEnd > now &&
                (enabledKindSet.contains(record.kind) || (record.isCompleted && !record.isClaimed))
            }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
                return lhs.periodStart < rhs.periodStart
            }

        let history = allChallenges
            .filter { $0.periodEnd <= now }
            .sorted { lhs, rhs in
                if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd > rhs.periodEnd }
                return lhs.kind.sortOrder < rhs.kind.sortOrder
            }
            .prefix(12)

        return ChallengeDuplicateResolver.deduplicatedRecords(active + history)
    }
}

private struct ChallengeBoardEmptyState: View {
    let isPaused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(isPaused ? "Challenges sind pausiert" : "Missionen werden vorbereitet")
                .font(.headline)

            Text(isPaused ? "Du kannst Tages-, Wochen-, Monats- oder Jahresmissionen jederzeit in den Einstellungen wieder aktivieren." : "Sobald die aktuellen Challenge-Zeiträume angelegt sind, erscheinen hier deine aktiven Missionen mit Fortschritt und nächstem Ziel.")
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
