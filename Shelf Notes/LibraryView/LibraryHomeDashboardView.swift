//
//  LibraryHomeDashboardView.swift
//  Shelf Notes
//
//  Smart Shelf home area shown above the library results in the home state.
//

import SwiftUI

struct LibraryHomeResolvedLane: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let books: [Book]
    let presentationsByBookID: [UUID: LibraryBookPresentation]
}

struct LibraryHomeDashboardView: View {
    let snapshot: LibraryView.LibraryHomeSnapshot
    let mode: LibraryHomeModeOption
    let appearance: LibraryRowAppearanceSnapshot
    let continueReadingBook: Book?
    let continueReadingPresentation: LibraryBookPresentation?
    let insightSnapshot: LibraryView.LibraryHomeInsightSnapshot
    let lanes: [LibraryHomeResolvedLane]
    let quickFilterSnapshot: LibraryView.LibraryQuickFilterSnapshot
    let roulette: LibraryView.LibraryBookRoulette
    let rouletteBooksByID: [UUID: Book]
    let maintenanceSummary: LibraryView.LibraryShelfMaintenanceSummary
    let showsMaintenance: Bool
    let showsRoulette: Bool
    let onSelectTag: (String) -> Void
    let onSelectCollection: (String) -> Void
    let onSelectSmartFilter: (LibraryView.LibrarySmartFilter) -> Void

    private var showsLanes: Bool {
        mode == .full && lanes.isEmpty == false
    }

    private var showsMaintenanceCard: Bool {
        showsMaintenance && maintenanceSummary.isEmpty == false
    }

    private var showsRouletteCard: Bool {
        showsRoulette && roulette.isEmpty == false
    }

    private var showsQuickFilters: Bool {
        quickFilterSnapshot.isEmpty == false
    }

    private var showsInsights: Bool {
        insightSnapshot.isEmpty == false
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 82), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let continueReadingBook {
                LibraryContinueReadingCard(
                    book: continueReadingBook,
                    presentation: continueReadingPresentation,
                    appearance: appearance
                )
            }

            quickStats

            if showsInsights {
                LibraryHomeInsightsCard(snapshot: insightSnapshot)
            }

            if showsQuickFilters {
                LibraryQuickFilterChipsView(
                    snapshot: quickFilterSnapshot,
                    onSelectTag: onSelectTag,
                    onSelectCollection: onSelectCollection
                )
            }

            if showsRouletteCard {
                LibraryBookRouletteCard(
                    roulette: roulette,
                    booksByID: rouletteBooksByID,
                    appearance: appearance
                )
            }

            if showsMaintenanceCard {
                LibraryShelfMaintenanceCard(
                    summary: maintenanceSummary,
                    onSelectFilter: onSelectSmartFilter
                )
            }

            if showsLanes {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(lanes) { lane in
                        LibraryShelfLaneView(
                            lane: lane,
                            appearance: appearance
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Smart Shelf, persönlicher Bibliotheksbereich")
    }

    private var quickStats: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(snapshot.quickStats) { stat in
                LibraryHomeStatCard(stat: stat)
            }
        }
    }
}
