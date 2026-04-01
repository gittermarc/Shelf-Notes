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
    @State var scope: Scope = .all
    @State var activityMetric: ActivityMetric = .readingDays

    @State var sourceSnapshot: StatisticsSourceSnapshot? = nil
    @State var statsCache: StatsCache? = nil
    @State var heatmapCache: HeatmapCache? = nil
    @State var isUpdatingStatsCache: Bool = false
    @State var isUpdatingHeatmapCache: Bool = false

    enum Scope: String, CaseIterable, Identifiable, Sendable {
        case all = "Alle"
        case finished = "Gelesen"
        case reading = "Lese ich"
        case toRead = "Will lesen"
        var id: String { rawValue }
    }

    enum ActivityMetric: String, CaseIterable, Identifiable, Sendable {
        case readingDays = "Lesetage"
        case readingMinutes = "Leseminuten"
        case completions = "Abschlüsse"
        var id: String { rawValue }

        var unitSuffix: String {
            switch self {
            case .readingMinutes:
                return " min"
            case .readingDays, .completions:
                return ""
            }
        }
    }

    var body: some View {
        let signature = booksSignature(books)
        let statsKey = makeStatsCacheKey(signature: signature)
        let heatmapKey = makeHeatmapCacheKey(signature: signature)
        let exactStatsCache = statsCache?.key == statsKey ? statsCache : nil
        let scopeStatsCache: StatsCache? = {
            guard let cache = statsCache,
                  cache.key.scope == scope,
                  cache.key.booksSignature == signature else {
                return nil
            }
            return cache
        }()
        let exactHeatmapCache = heatmapCache?.key == heatmapKey ? heatmapCache : nil

        Group {
            if books.isEmpty {
                ContentUnavailableView(
                    "Noch keine Daten",
                    systemImage: "chart.bar",
                    description: Text("Füge Bücher hinzu — dann wird’s hier schön nerdig. 📈")
                )
                .padding(.horizontal)
            } else {
                let sameBooksStatsCache: StatsCache? = {
                    guard let cache = statsCache,
                          cache.key.booksSignature == signature else {
                        return nil
                    }
                    return cache
                }()
                let summary = exactStatsCache?.summary
                let yearOptions = sameBooksStatsCache?.summary.yearOptions ?? [selectedYear]

                ScrollView {
                    VStack(spacing: 14) {
                        headerCard(summary: summary)
                        yearAndScopeCard(yearOptions: yearOptions)
                        overviewGrid(summary: summary)
                        readingChartsCard(statsKey: statsKey, cache: exactStatsCache)
                        activityHeatmapCard(heatmapKey: heatmapKey, cache: exactHeatmapCache)
                        topListsCard(cache: scopeStatsCache)
                        nerdCornerCard(summary: summary, cache: exactStatsCache)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 18)
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: signature) {
            guard !books.isEmpty else {
                sourceSnapshot = nil
                statsCache = nil
                heatmapCache = nil
                return
            }

            sourceSnapshot = StatisticsSourceSnapshot(signature: signature, books: books)
        }
        .task(id: statsKey) {
            guard !books.isEmpty else {
                statsCache = nil
                return
            }

            isUpdatingStatsCache = true
            defer { isUpdatingStatsCache = false }

            let source = currentSourceSnapshot(for: signature)
            let pipeline = makeComputePipeline(for: source)
            let cache = await pipeline.makeStatsCache(for: statsKey)
            guard !Task.isCancelled else { return }
            statsCache = cache
        }
        .task(id: heatmapKey) {
            guard !books.isEmpty else {
                heatmapCache = nil
                return
            }

            isUpdatingHeatmapCache = true
            defer { isUpdatingHeatmapCache = false }

            let source = currentSourceSnapshot(for: signature)
            let pipeline = makeComputePipeline(for: source)
            let cache = await pipeline.makeHeatmapCache(for: heatmapKey)
            guard !Task.isCancelled else { return }
            heatmapCache = cache
        }
    }
}
