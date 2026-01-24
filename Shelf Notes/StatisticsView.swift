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
        NavigationStack {
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
        }
    }
}
