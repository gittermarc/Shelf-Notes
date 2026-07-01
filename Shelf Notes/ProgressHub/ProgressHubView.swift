//
//  ProgressHubView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 28.01.26.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Consolidated progress hub ("Fortschritt") that bundles:
/// - Statistiken
/// - Leseziele
/// - Zeitleiste
/// - Challenges
struct ProgressHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var books: [Book]

    @Query(sort: \ReadingGoal.year, order: .reverse)
    private var goals: [ReadingGoal]

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @StateObject private var metricsModel = ProgressHubMetricsModel()

    var body: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        let refreshToken = ProgressHubMetricsModel.makeRefreshToken(
            year: currentYear,
            books: books,
            goals: goals
        )

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if books.isEmpty {
                        emptyHintCard
                    }

                    heroCard
                    quickLinksGrid

                    NavigationLink {
                        ChallengesView()
                    } label: {
                        ChallengesSummaryCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
                .padding(.top, 12)
            }
            .navigationTitle("Fortschritt")
            .navigationBarTitleDisplayMode(.large)
        }
        .task(id: refreshToken) {
            metricsModel.refreshSourceAndTrack(
                year: currentYear,
                books: books,
                goals: goals,
                modelContext: modelContext
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionsDidChange)) { _ in
            requestSessionMetricsRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                requestSessionMetricsRefresh()
            }
        }
    }

    private func requestSessionMetricsRefresh() {
        metricsModel.requestSessionMetricsRefresh(modelContext: modelContext)
    }

    private var emptyHintCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Noch leer – aber nicht lange")
                        .font(.headline)

                    Text("Füg ein paar Bücher hinzu oder logge eine Session. Dann wird das hier dein persönliches Fortschritts-Dashboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Hero

    private var heroCard: some View {
        let m = metricsModel.metrics
        let y = m.year
        let finishedThisYear = m.finishedThisYear
        let goalTarget = m.goalTarget
        let last7 = (minutes: m.minutesLast7, activeDays: m.activeDaysLast7, currentStreak: m.currentStreak)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dein Stand")
                        .font(.headline)

                    Text("Kurz & ehrlich: Das zählt gerade.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(String(y))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            let columns: [GridItem] = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                MetricTile(
                    systemImage: "checkmark.seal",
                    title: "Abschlüsse",
                    value: goalTarget != nil ? "\(finishedThisYear) / \(goalTarget!)" : "\(finishedThisYear)",
                    caption: goalTarget != nil ? "Jahresziel" : "dieses Jahr"
                )

                MetricTile(
                    systemImage: "clock",
                    title: "Minuten",
                    value: "\(last7.minutes)",
                    caption: "letzte 7 Tage"
                )

                MetricTile(
                    systemImage: "calendar",
                    title: "Lesetage",
                    value: "\(last7.activeDays)",
                    caption: "letzte 7 Tage"
                )

                MetricTile(
                    systemImage: "flame",
                    title: "Streak",
                    value: "\(last7.currentStreak)",
                    caption: "Tage am Stück"
                )
            }

            if goalTarget == nil {
                Text("Tipp: Setz dir ein Jahresziel – dann fühlt sich jeder Abschluss wie ein kleiner Sieg an.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Quick links

    private var quickLinksGrid: some View {
        let columns: [GridItem] = isPad
            ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            NavigationLink {
                StatisticsView()
            } label: {
                HubTile(
                    systemImage: "chart.bar.xaxis",
                    title: "Statistiken",
                    subtitle: "Charts, Heatmap & Nerd-Ecke"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoalsView()
            } label: {
                HubTile(
                    systemImage: "target",
                    title: "Leseziele",
                    subtitle: "Jahresziel & Fortschritt"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ReadingTimelineView()
            } label: {
                HubTile(
                    systemImage: "clock",
                    title: "Zeitleiste",
                    subtitle: "Dein Lesen als Zeitstrahl"
                )
            }
            .buttonStyle(.plain)
        }
    }

}

// MARK: - UI components

private struct HubTile: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct MetricTile: View {
    let systemImage: String
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
