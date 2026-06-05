//
//  StatisticsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 03.01.26.
//

import SwiftUI
import SwiftData

#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @Query var books: [Book]

    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State var scope: StatisticsScope = .all
    @State var activityMetric: StatisticsActivityMetric = .readingDays
    @StateObject var sourceStore = StatisticsSourceStore()

    var body: some View {
        let sourceState = sourceStore.makeViewState(
            selectedYear: selectedYear,
            scope: scope,
            activityMetric: activityMetric
        )

        Group {
            if books.isEmpty {
                ContentUnavailableView(
                    "Noch keine Daten",
                    systemImage: "chart.bar",
                    description: Text("Füge Bücher hinzu — dann wird’s hier schön nerdig. 📈")
                )
                .padding(.horizontal)
            } else {
                let summary = sourceState.exactStatsCache?.summary
                let yearOptions = sourceState.yearOptions

                ScrollView {
                    VStack(spacing: 14) {
                        headerCard(summary: summary)
                        yearAndScopeCard(yearOptions: yearOptions)
                        overviewGrid(summary: summary)
                        readingChartsCard(
                            statsKey: sourceState.statsKey,
                            cache: sourceState.exactStatsCache
                        )
                        activityHeatmapCard(
                            heatmapKey: sourceState.heatmapKey,
                            cache: sourceState.exactHeatmapCache
                        )
                        topListsCard(cache: sourceState.scopeStatsCache)
                        nerdCornerCard(summary: summary, cache: sourceState.exactStatsCache)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 18)
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: books.count) {
            sourceStore.refreshSourceAndTrack(books: books)
        }
        .task(id: sourceState.statsKey) {
            guard !books.isEmpty, let statsKey = sourceState.statsKey else { return }
            await sourceStore.refreshStatsCache(for: statsKey)
        }
        .task(id: sourceState.sessionSourceRequestToken) {
            guard !books.isEmpty, sourceState.sessionSourceRequestToken != nil else { return }
            sourceStore.refreshSessionSourceAndTrack(books: books)
        }
        .task(id: sourceState.heatmapKey) {
            guard !books.isEmpty, let heatmapKey = sourceState.heatmapKey else { return }
            await sourceStore.refreshHeatmapCache(for: heatmapKey)
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionsDidChange)) { _ in
            sourceStore.invalidateSessionSource()
            if activityMetric == .readingMinutes {
                sourceStore.refreshSessionSourceAndTrack(books: books)
            }
        }
    }
}
