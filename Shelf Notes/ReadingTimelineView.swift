//
//  ReadingTimelineView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 09.01.26.
//

import SwiftUI
import SwiftData

/// A visually focused, horizontally scrollable reading timeline.
///
/// - Data source: finished books.
/// - Sorting key: `readTo ?? readFrom ?? createdAt`.
/// - UI: year chips scrubber + year summary cards + cover tiles on a horizontal axis.
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

    // A stable height prevents SwiftUI from collapsing the horizontal scroll view
    // (which can lead to half-clipped cards/covers).
    private let timelineScrollHeight: CGFloat = 380

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
                // Default selection: first year if available
                if selectedYear == nil {
                    selectedYear = years.first
                }
            }
        }
    }

    // MARK: - Main content

    private var content: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                header

                // ✅ Year Chips Scrubber (Apple Books meets Letterboxd)
                if !years.isEmpty {
                    YearChipsBar(
                        years: years,
                        selectedYear: $selectedYear
                    ) { year in
                        selectedYear = year
                        jumpToYear = year
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: 22) {
                        ForEach(timelineItems) { item in
                            switch item.kind {
                            case .year(let y, let stats):
                                YearSummaryMarker(
                                    year: y,
                                    stats: stats
                                )
                                .id(scrollID(forYear: y))

                            case .book(let book, let date):
                                TimelineBookTile(book: book, date: date)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    // The time axis line that runs behind the dots.
                    .background(alignment: .bottom) {
                        Rectangle()
                            .fill(.secondary.opacity(0.25))
                            .frame(height: 2)
                            .padding(.horizontal, 16)
                            .offset(y: -8)
                    }
                }
                // ✅ Critical: give the horizontal scroll view a stable height so content isn't clipped.
                .frame(height: timelineScrollHeight)
                // ✅ Adds internal top/bottom breathing room; helps shadows & tall content.
                .contentMargins(.vertical, 8, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .onChange(of: jumpToYear) { _, newValue in
                    guard let y = newValue else { return }
                    withAnimation(.snappy) {
                        proxy.scrollTo(scrollID(forYear: y), anchor: .leading)
                    }
                }

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
            Text("Tipp: Mit den Jahres-Chips oben kannst du superschnell scrubben.")
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

            // For the little cover preview strip: earliest 4 of that year
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
        // For finished books, readTo is the best signal. Fall back to readFrom / createdAt.
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

// MARK: - UI pieces

private struct YearChipsBar: View {
    let years: [Int]
    @Binding var selectedYear: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(years, id: \.self) { y in
                    let isSelected = (selectedYear == y)

                    Button {
                        onSelect(y)
                    } label: {
                        Text(String(y))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            // ✅ tighter chips
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.primary : Color.secondary.opacity(0.15))
                            }
                            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jahr \(y)")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            // ✅ remove the “too much air” above/below the chips row
            .padding(.vertical, 0)
        }
        .scrollClipDisabled()
        .contentMargins(.vertical, 0, for: .scrollContent)
    }
}

private struct YearSummaryMarker: View {
    let year: Int
    let stats: YearStats

    var body: some View {
        VStack(spacing: 10) {
            YearSummaryCard(year: year, stats: stats)

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2, height: 18)

            TimelineDot()
        }
        .padding(.bottom, 2)
        .frame(width: 270)
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
                            size: CGSize(width: 44, height: 66),
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
                        size: CGSize(width: 120, height: 176),
                        cornerRadius: 16,
                        contentMode: .fill
                    )
                    .shadow(radius: 10, y: 6)
                    .overlay(alignment: .bottomLeading) {
                        // Subtle overlay so the title is readable even on bright covers.
                        LinearGradient(
                            colors: [.black.opacity(0.0), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .frame(width: 140)
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
