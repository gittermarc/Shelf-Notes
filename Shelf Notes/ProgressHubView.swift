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

    @Query private var books: [Book]

    @Query(sort: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)])
    private var challenges: [ChallengeRecord]

    @Query(sort: \ReadingGoal.year, order: .reverse)
    private var goals: [ReadingGoal]

    @Query(sort: \ReadingSession.startedAt, order: .reverse)
    private var sessions: [ReadingSession]

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
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
                        ChallengesSummaryCard(challenges: challenges)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
                .padding(.top, 12)
            }
            .navigationTitle("Fortschritt")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // Make sure the initial weekly/monthly challenges exist.
                ChallengeEngine.ensureCurrentChallenges(modelContext: modelContext)
            }
        }
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
        let y = Calendar.current.component(.year, from: Date())
        let finishedThisYear = finishedBooks(in: y).count
        let goalTarget = goalTargetCount(for: y)

        let last7 = last7DaysSessionStats()

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
                    title: "Gelesen",
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

    // MARK: - Data helpers

    private func finishedBooks(in year: Int) -> [Book] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date.distantFuture

        return books.filter { b in
            guard b.status == .finished else { return false }
            let key = b.readTo ?? b.readFrom
            guard let d = key else { return false }
            return d >= start && d < end
        }
    }

    private func goalTargetCount(for year: Int) -> Int? {
        goals.first(where: { $0.year == year })?.targetCount
    }

    private func last7DaysSessionStats() -> (minutes: Int, activeDays: Int, currentStreak: Int) {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let today = cal.startOfDay(for: Date())
        let windowStart = cal.date(byAdding: .day, value: -6, to: today) ?? today

        var secondsTotal = 0
        var daysWithActivityWindow = Set<Date>()
        var daysWithActivityAll = Set<Date>()

        for s in sessions {
            let day = cal.startOfDay(for: s.startedAt)
            if s.durationSeconds > 0 { daysWithActivityAll.insert(day) }

            // sessions are sorted desc, so once we pass the window we can stop collecting window-stats.
            if day < windowStart { continue }
            secondsTotal += max(0, s.durationSeconds)
            if s.durationSeconds > 0 { daysWithActivityWindow.insert(day) }
        }

        // streak from today backwards (not limited to the 7-day window)
        var streak = 0
        var cursor = today
        while daysWithActivityAll.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        let minutes = Int((Double(secondsTotal) / 60.0).rounded())
        return (minutes: minutes, activeDays: daysWithActivityWindow.count, currentStreak: streak)
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
