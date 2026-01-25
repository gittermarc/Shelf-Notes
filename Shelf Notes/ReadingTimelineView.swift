//
//  ReadingTimelineView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 09.01.26.
//

import SwiftUI
import SwiftData
import UIKit

/// A visually focused, horizontally scrollable reading timeline.
///
/// - Data source: finished books.
/// - Sorting key: `readTo ?? readFrom ?? createdAt`.
/// - UI: year mini-map (auto-highlight) + year summary cards + cover tiles on a horizontal axis.
struct ReadingTimelineView: View {
    // Only finished books.
    //
    // NOTE: SwiftData's #Predicate macro does NOT like referencing enum cases inside the predicate
    // (e.g. ReadingStatus.finished.rawValue). It can produce:
    // "Key path cannot refer to enum case 'finished'"
    //
    // So we filter by the persisted raw string value directly.
    // (v2: stable code "finished"; v1 legacy: "Gelesen")
    @Query(filter: #Predicate<Book> { $0.statusRawValue == "finished" || $0.statusRawValue == "Gelesen" })
    private var finishedBooks: [Book]

    @StateObject private var vm = ReadingTimelineViewModel()

    private let coordinateSpaceName = "timelineScroll"

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // MARK: - Tunables (responsive)

    private var timelineScrollHeight: CGFloat {
        // Less empty space under mini-map on iPhone; more room on iPad for larger cards/covers.
        isPad ? 520 : 340
    }

    private var coverSize: CGSize {
        isPad ? CGSize(width: 160, height: 236) : CGSize(width: 132, height: 194)
    }

    private var coverTileWidth: CGFloat {
        isPad ? 176 : 150
    }

    private var yearCardWidth: CGFloat {
        isPad ? 360 : 300
    }

    private var yearPreviewCoverSize: CGSize {
        isPad ? CGSize(width: 54, height: 80) : CGSize(width: 48, height: 72)
    }

    var body: some View {
        NavigationStack {
            Group {
                if finishedBooks.isEmpty {
                    emptyState
                } else if vm.items.isEmpty {
                    loadingState
                } else {
                    content
                }
            }
            .navigationTitle("Zeitleiste")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !vm.years.isEmpty {
                        Menu {
                            Button("Zum Anfang") {
                                vm.requestJumpToStart()
                            }
                            Button("Zum Ende") {
                                vm.requestJumpToEnd()
                            }
                            Divider()

                            ForEach(vm.years, id: \.self) { y in
                                Button(String(y)) {
                                    vm.requestJump(to: y)
                                }
                            }
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Zu Jahr springen")
                    }
                }
            }
            .task(id: finishedBooks.map { $0.id }) {
                // Keep view model derived data in sync with SwiftData changes.
                vm.setBooks(finishedBooks)
            }
        }
    }

    // MARK: - Main content

    private var content: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 6) {
                header

                // ✅ Mini-Map (thin year bar) with auto-highlight while scrolling
                if !vm.years.isEmpty {
                    ReadingTimelineMiniMapBar(
                        years: vm.years,
                        selectedYear: $vm.selectedYear
                    ) { year in
                        vm.requestJump(to: year)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 4)
                }

                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: isPad ? 26 : 22) {
                            ForEach(vm.items) { item in
                                switch item.kind {
                                case .year(let y, let stats):
                                    ReadingTimelineYearSectionView(
                                        year: y,
                                        stats: stats,
                                        cardWidth: yearCardWidth,
                                        previewCoverSize: yearPreviewCoverSize,
                                        coordinateSpaceName: coordinateSpaceName
                                    )
                                    .id(vm.scrollID(forYear: y))

                                case .book(let book, let date):
                                    ReadingTimelineBookRowView(
                                        book: book,
                                        date: date,
                                        coverSize: coverSize,
                                        tileWidth: coverTileWidth
                                    )
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                        .background(alignment: .bottom) {
                            Rectangle()
                                .fill(.secondary.opacity(0.25))
                                .frame(height: 2)
                                .padding(.horizontal, 16)
                                .offset(y: -8)
                        }
                    }
                    .coordinateSpace(name: coordinateSpaceName)
                    // ✅ Less “air” on iPhone, bigger visuals on iPad
                    .frame(height: timelineScrollHeight)
                    .contentMargins(.vertical, 2, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .onAppear {
                        vm.updateViewportWidth(geo.size.width)
                    }
                    .onChange(of: geo.size.width) { _, newValue in
                        vm.updateViewportWidth(newValue)
                    }
                    .onChange(of: vm.jumpToYear) { _, newValue in
                        guard let y = newValue else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(vm.scrollID(forYear: y), anchor: .leading)
                        }
                        // Reset so selecting the same year again still triggers a jump.
                        vm.jumpToYear = nil
                    }
                    // ✅ Receive positions and auto-highlight the year closest to viewport center
                    .onPreferenceChange(ReadingTimelineYearMarkerMidXPreferenceKey.self) { newValue in
                        vm.updateYearMarkerPositions(newValue)
                    }
                }
                .frame(height: timelineScrollHeight)

                footerHint
            }
            .padding(.vertical, 6)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Deine gelesenen Bücher als Zeitstrahl")
                .font(.headline)

            Text("Scroll nach rechts für die Zukunft. Scroll nach links für „Hä, was habe ich 2018 eigentlich gelesen?“ 😄")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 0)
    }

    private var footerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .foregroundStyle(.secondary)
            Text("Tipp: In der Mini-Map oben wird beim Scrollen automatisch das aktive Jahr markiert.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Zeitleiste wird gebaut …")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch keine Zeitleiste", systemImage: "clock")
        } description: {
            Text("Sobald du ein Buch als „Gelesen“ markierst, erscheint es hier – chronologisch sortiert.")
        } actions: {
            NavigationLink {
                LibraryView()
            } label: {
                Text("Zur Bibliothek")
            }
        }
        .padding()
    }
}
