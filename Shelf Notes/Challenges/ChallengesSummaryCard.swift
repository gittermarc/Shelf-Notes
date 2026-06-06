//
//  ChallengesSummaryCard.swift
//  Shelf Notes
//

import SwiftUI
import SwiftData

struct ChallengesSummaryCard: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(ChallengePreferencesStorageKey.enabledKinds) private var enabledKindsRaw: String = ChallengePreferencesStore.defaultEnabledKindsRaw
    @AppStorage(ChallengePreferencesStorageKey.preset) private var presetRaw: String = ChallengePreferencesStore.defaultPresetRaw

    @State private var sourceSnapshot: ChallengeSourceSnapshot = .empty
    @State private var progressByID: [UUID: ChallengeEngine.ChallengeProgress] = [:]

    private var challengePreferences: ChallengePreferences {
        ChallengePreferencesStore.preferences(enabledKindsRaw: enabledKindsRaw, presetRaw: presetRaw)
    }

    var body: some View {
        let preferences = challengePreferences
        let dashboard = ChallengeDashboardBuilder.make(
            challenges: sourceSnapshot.dashboardRecords,
            progressByID: progressByID,
            enabledKinds: preferences.enabledKinds
        )

        VStack(alignment: .leading, spacing: 13) {
            header(unclaimedCount: dashboard.unclaimedCount)

            if let todayFocus = dashboard.todayFocus {
                summaryTodayFocus(todayFocus)
            } else if let hero = dashboard.hero {
                summaryHero(hero)
            } else {
                Text(preferences.enabledKinds.isEmpty ? "Challenges sind pausiert." : "Aktuelle Challenges werden vorbereitet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(dashboard.activeItems) { item in
                ChallengeSummaryMiniRow(item: item)
            }

            if dashboard.todayFocus == nil && dashboard.activeItems.isEmpty && dashboard.hero == nil {
                Text(preferences.enabledKinds.isEmpty ? "Aktiviere Missionen in den Einstellungen, wenn du wieder Challenge-Druck willst." : "Logge eine Lesesession, dann wird dein Fortschritt hier sichtbar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .task(id: challengePreferences.storageSignature) {
            await refreshProgress()
        }
        .onAppear {
            Task { await refreshProgress(ensuringCurrent: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionsDidChange)) { _ in
            Task { await refreshProgress(ensuringCurrent: false) }
        }
        .accessibilityElement(children: .combine)
    }

    private func header(unclaimedCount: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Challenges")
                    .font(.headline)
                Text("Heute und nächster kleiner Lesesieg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if unclaimedCount > 0 {
                Label("\(unclaimedCount)", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(unclaimedCount) Belohnungen bereit")
            }

            Image(systemName: "trophy")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private func summaryTodayFocus(_ focus: ChallengeDashboardTodayFocus) -> some View {
        HStack(spacing: 12) {
            ChallengeProgressRing(
                fraction: focus.item.progressFraction,
                lineWidth: 7,
                size: 54
            )

            VStack(alignment: .leading, spacing: 4) {
                ChallengeCadencePill(kind: focus.item.kind, label: focus.headline, isProminent: true)

                Text(focus.actionText)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(focus.item.progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heute im Fokus: \(focus.item.title), \(focus.item.progressText)")
    }

    private func summaryHero(_ hero: ChallengeDashboardHero) -> some View {
        HStack(spacing: 12) {
            ChallengeProgressRing(
                fraction: hero.progressFraction,
                lineWidth: 7,
                size: 54
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(hero.title)
                    .font(.subheadline.weight(.semibold))

                Text(hero.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(hero.progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @MainActor
    private func refreshProgress(ensuringCurrent: Bool = true) async {
        let preferences = challengePreferences
        if ensuringCurrent {
            await ChallengeRefreshCoordinator.prepareCurrentChallenges(
                modelContext: modelContext,
                enabledKinds: preferences.enabledKinds
            )
        }

        let nextSnapshot = ChallengeSourceStore.makeSnapshot(
            modelContext: modelContext,
            enabledKinds: preferences.enabledKinds,
            includeHistory: false
        )
        let map = await ChallengeRefreshCoordinator.computeProgressMap(
            for: nextSnapshot.progressRecords,
            modelContext: modelContext
        )
        sourceSnapshot = nextSnapshot
        progressByID = map
    }
}

private struct ChallengeSummaryMiniRow: View {
    let item: ChallengeDashboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.badgeSystemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(item.kind.displayName)
                    .font(.caption.weight(.semibold))

                Spacer()

                Text(item.timeRemainingText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: item.progressFraction)
                .progressViewStyle(.linear)

            HStack {
                Text(item.progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(item.remainingText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
