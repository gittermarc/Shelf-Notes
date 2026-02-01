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
    @Environment(\.modelContext) private var modelContext
    @Query var books: [Book]

    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State var scope: Scope = .all
    @State var activityMetric: ActivityMetric = .readingDays

    // Cached aggregations to avoid re-computing expensive stats on every UI update
    // (e.g. expanding/collapsing DisclosureGroups).
    @State var statsCache: StatsCache? = nil
    @State var heatmapCache: HeatmapCache? = nil
    @State var isUpdatingStatsCache: Bool = false
    @State var isUpdatingHeatmapCache: Bool = false

    enum Scope: String, CaseIterable, Identifiable {
        case all = "Alle"
        case finished = "Gelesen"
        case reading = "Lese ich"
        case toRead = "Will lesen"
        var id: String { rawValue }
    }

    enum ActivityMetric: String, CaseIterable, Identifiable {
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

        Group {
            if books.isEmpty {
                ContentUnavailableView(
                    "Noch keine Daten",
                    systemImage: "chart.bar",
                    description: Text("Füge Bücher hinzu — dann wird’s hier schön nerdig. 📈")
                )
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        headerCard
                        yearAndScopeCard
                        overviewGrid
                        readingChartsCard
                        activityHeatmapCard
                        topListsCard
                        nerdCornerCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 18)
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)

        // Recompute caches only when their inputs change.
        .task(id: statsKey) {
            guard !books.isEmpty else {
                statsCache = nil
                return
            }

            isUpdatingStatsCache = true
            defer { isUpdatingStatsCache = false }

            // Let the UI render first; then crunch numbers.
            await Task.yield()
            statsCache = computeStatsCache(for: statsKey)
        }
        .task(id: heatmapKey) {
            guard !books.isEmpty else {
                heatmapCache = nil
                return
            }

            isUpdatingHeatmapCache = true
            defer { isUpdatingHeatmapCache = false }

            await Task.yield()
            heatmapCache = computeHeatmapCache(for: heatmapKey)
        }
    }
}
