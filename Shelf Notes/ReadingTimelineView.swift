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
    @Query(filter: #Predicate<Book> { $0.statusRawValue == "Gelesen" })
    private var finishedBooks: [Book]

    @State private var jumpToYear: Int?
    @State private var selectedYear: Int?

    // Mini-map auto highlight support
    @State private var timelineViewportWidth: CGFloat = 0
    @State private var yearMarkerMidXByYear: [Int: CGFloat] = [:]

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
                if timelineItems.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Zeitleiste")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !years.isEmpty {
                        Menu {
                            Button("Zum Anfang") {
                                if let first = years.first {
                                    selectedYear = first
                                    jumpToYear = first
                                }
                            }
                            Button("Zum Ende") {
                                if let last = years.last {
                                    selectedYear = last
                                    jumpToYear = last
                                }
                            }
                            Divider()

                            ForEach(years, id: \.self) { y in
                                Button(String(y)) {
                                    selectedYear = y
                                    jumpToYear = y
                                }
                            }
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Zu Jahr springen")
                    }
                }
            }
            .onAppear {
                if selectedYear == nil {
                    selectedYear = years.first
                }
            }
        }
    }

    // MARK: - Main content

    private var content: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 6) {
                header

                // ✅ Mini-Map (thin year bar) with auto-highlight while scrolling
                if !years.isEmpty {
                    YearMiniMapBar(
                        years: years,
                        selectedYear: $selectedYear
                    ) { year in
                        selectedYear = year
                        jumpToYear = year
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 4)
                }

                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: isPad ? 26 : 22) {
                            ForEach(timelineItems) { item in
                                switch item.kind {
                                case .year(let y, let stats):
                                    YearSummaryMarker(
                                        year: y,
                                        stats: stats,
                                        cardWidth: yearCardWidth,
                                        previewCoverSize: yearPreviewCoverSize
                                    )
                                    .id(scrollID(forYear: y))
                                    // ✅ Track year marker positions for auto-highlight
                                    .background(YearMarkerPositionReporter(year: y))

                                case .book(let book, let date):
                                    TimelineBookTile(
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
                    .coordinateSpace(name: "timelineScroll")
                    // ✅ Less “air” on iPhone, bigger visuals on iPad
                    .frame(height: timelineScrollHeight)
                    .contentMargins(.vertical, 2, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .onAppear {
                        timelineViewportWidth = geo.size.width
                    }
                    .onChange(of: geo.size.width) { _, newValue in
                        timelineViewportWidth = newValue
                    }
                    .onChange(of: jumpToYear) { _, newValue in
                        guard let y = newValue else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(scrollID(forYear: y), anchor: .leading)
                        }
                    }
                    // ✅ Receive positions and auto-highlight the year closest to viewport center
                    .onPreferenceChange(YearMarkerMidXPreferenceKey.self) { newValue in
                        yearMarkerMidXByYear = newValue
                        updateAutoHighlightedYearIfNeeded()
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

    // MARK: - Auto highlight logic

    private func updateAutoHighlightedYearIfNeeded() {
        guard timelineViewportWidth > 0 else { return }
        let centerX = timelineViewportWidth / 2

        // Find the year marker closest to the center of the visible area.
        var bestYear: Int?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for (year, midX) in yearMarkerMidXByYear {
            let dist = abs(midX - centerX)
            if dist < bestDistance {
                bestDistance = dist
                bestYear = year
            }
        }

        guard let bestYear else { return }

        // Only update if it actually changed, to avoid needless state churn.
        if selectedYear != bestYear {
            selectedYear = bestYear
        }
    }

    // MARK: - Data preparation

    private var years: [Int] {
        let ys = timelineEntries.map { Calendar.current.component(.year, from: $0.date) }
        return Array(Set(ys)).sorted()
    }

    private var timelineEntries: [(book: Book, date: Date)] {
        finishedBooks
            .map { ($0, completionDate(for: $0)) }
            .sorted { $0.1 < $1.1 }
    }

    private var yearStatsByYear: [Int: YearStats] {
        var dict: [Int: [YearEntry]] = [:]

        for (book, date) in timelineEntries {
            let y = Calendar.current.component(.year, from: date)
            dict[y, default: []].append(YearEntry(book: book, date: date))
        }

        var out: [Int: YearStats] = [:]
        for (year, entries) in dict {
            let count = entries.count

            let ratedAverages: [Double] = entries.compactMap { $0.book.userRatingAverage }
            let ratedCount = ratedAverages.count
            let avgRating: Double? = ratedAverages.isEmpty
                ? nil
                : (ratedAverages.reduce(0, +) / Double(ratedAverages.count))

            let sortedByDate = entries.sorted { $0.date < $1.date }
            let firstDate = sortedByDate.first?.date
            let lastDate = sortedByDate.last?.date

            let previewBooks = sortedByDate.prefix(4).map { $0.book }

            out[year] = YearStats(
                year: year,
                count: count,
                ratedCount: ratedCount,
                averageRating: avgRating,
                firstDate: firstDate,
                lastDate: lastDate,
                previewBooks: previewBooks
            )
        }

        return out
    }

    private var timelineItems: [TimelineItem] {
        guard !timelineEntries.isEmpty else { return [] }

        var items: [TimelineItem] = []
        var lastYear: Int?

        for (book, date) in timelineEntries {
            let y = Calendar.current.component(.year, from: date)

            if lastYear != y {
                let stats = yearStatsByYear[y] ?? YearStats(year: y, count: 0, ratedCount: 0, averageRating: nil, firstDate: nil, lastDate: nil, previewBooks: [])
                items.append(TimelineItem(kind: .year(y, stats)))
                lastYear = y
            }

            items.append(TimelineItem(kind: .book(book, date)))
        }

        return items
    }

    private func completionDate(for book: Book) -> Date {
        book.readTo ?? book.readFrom ?? book.createdAt
    }

    private func scrollID(forYear year: Int) -> String {
        "year-\(year)"
    }
}

// MARK: - Models used by the timeline

private struct TimelineItem: Identifiable {
    enum Kind {
        case year(Int, YearStats)
        case book(Book, Date)
    }

    let id = UUID()
    let kind: Kind
}

private struct YearEntry {
    let book: Book
    let date: Date
}

private struct YearStats {
    let year: Int
    let count: Int
    let ratedCount: Int
    let averageRating: Double?
    let firstDate: Date?
    let lastDate: Date?
    let previewBooks: [Book]

    var dateRangeText: String? {
        guard let firstDate, let lastDate else { return nil }
        let start = firstDate.formatted(.dateTime.day().month(.twoDigits))
        let end = lastDate.formatted(.dateTime.day().month(.twoDigits))
        return "\(start) – \(end)"
    }

    var averageRatingText: String? {
        guard let averageRating else { return nil }
        let rounded = (averageRating * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }
}

// MARK: - Mini-map position tracking

private struct YearMarkerPositionReporter: View {
    let year: Int

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: YearMarkerMidXPreferenceKey.self,
                    value: [year: proxy.frame(in: .named("timelineScroll")).midX]
                )
        }
    }
}

private struct YearMarkerMidXPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        // Merge dictionaries; newest wins.
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - UI pieces

/// Mini-Map: thin, compact year bar that highlights the current year.
/// Tap a year to jump to it.
private struct YearMiniMapBar: View {
    let years: [Int]
    @Binding var selectedYear: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(years, id: \.self) { y in
                        let isSelected = (selectedYear == y)

                        Button {
                            onSelect(y)
                        } label: {
                            Text(String(y))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? Color.primary : Color.secondary.opacity(0.12))
                                }
                                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                        }
                        .buttonStyle(.plain)
                        .id(y)
                        .accessibilityLabel("Jahr \(y)")
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 0)
            }
            .scrollClipDisabled()
            .contentMargins(.vertical, 0, for: .scrollContent)
            .onChange(of: selectedYear) { _, newValue in
                guard let y = newValue else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(y, anchor: .center)
                }
            }
        }
    }
}

private struct YearSummaryMarker: View {
    let year: Int
    let stats: YearStats
    let cardWidth: CGFloat
    let previewCoverSize: CGSize

    var body: some View {
        VStack(spacing: 10) {
            YearSummaryCard(
                year: year,
                stats: stats,
                previewCoverSize: previewCoverSize
            )

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2, height: 18)

            TimelineDot()
        }
        .padding(.bottom, 2)
        .frame(width: cardWidth)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.97)
                .opacity(phase.isIdentity ? 1.0 : 0.9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Jahr \(year), \(stats.count) Bücher")
    }
}

private struct YearSummaryCard: View {
    let year: Int
    let stats: YearStats
    let previewCoverSize: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()

                Spacer()

                Text("\(stats.count) \(stats.count == 1 ? "Buch" : "Bücher")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let avg = stats.averageRatingText {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text("Ø \(avg)")
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "star")
                        Text("Noch kein Ø-Rating")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if stats.ratedCount > 0, stats.ratedCount < stats.count {
                    Text("(\(stats.ratedCount) bewertet)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()
            }

            if let range = stats.dateRangeText {
                Text(range)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !stats.previewBooks.isEmpty {
                HStack(spacing: -10) {
                    ForEach(Array(stats.previewBooks.prefix(4).enumerated()), id: \.offset) { _, b in
                        BookCoverThumbnailView(
                            book: b,
                            size: previewCoverSize,
                            cornerRadius: 10,
                            contentMode: .fill
                        )
                        .shadow(radius: 6, y: 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.background.opacity(0.9), lineWidth: 2)
                        }
                        .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct TimelineBookTile: View {
    @Bindable var book: Book
    let date: Date
    let coverSize: CGSize
    let tileWidth: CGFloat

    private var dateText: String {
        date.formatted(.dateTime.day().month(.twoDigits))
    }

    private var yearText: String {
        date.formatted(.dateTime.year())
    }

    var body: some View {
        VStack(spacing: 10) {
            NavigationLink {
                BookDetailView(book: book)
            } label: {
                VStack(spacing: 10) {
                    BookCoverThumbnailView(
                        book: book,
                        size: coverSize,
                        cornerRadius: 18,
                        contentMode: .fill
                    )
                    .shadow(radius: 10, y: 6)
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.black.opacity(0.0), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(book.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(10)
                            .allowsHitTesting(false)
                    }

                    VStack(spacing: 2) {
                        Text(dateText)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                        Text(yearText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2, height: 18)

            TimelineDot(isHighlighted: true)
        }
        .frame(width: tileWidth)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.94)
                .opacity(phase.isIdentity ? 1.0 : 0.85)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title), beendet am \(date.formatted(date: .long, time: .omitted))")
    }
}

private struct TimelineDot: View {
    var isHighlighted: Bool = false

    var body: some View {
        Circle()
            .fill(isHighlighted ? Color.primary : Color.secondary.opacity(0.7))
            .frame(width: 10, height: 10)
            .overlay {
                Circle()
                    .stroke(.background.opacity(0.9), lineWidth: 2)
            }
            .shadow(radius: isHighlighted ? 4 : 0)
            .accessibilityHidden(true)
    }
}
