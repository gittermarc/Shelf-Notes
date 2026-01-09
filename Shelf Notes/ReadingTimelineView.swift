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
/// - Data source: finished books (`ReadingStatus.finished`).
/// - Sorting key: `readTo ?? readFrom ?? createdAt`.
/// - UI: year markers + cover tiles on a horizontal axis.
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
                            Button("Zum Anfang") { jumpToYear = years.first }
                            Button("Zum Ende") { jumpToYear = years.last }
                            Divider()

                            ForEach(years, id: \.self) { y in
                                Button(String(y)) { jumpToYear = y }
                            }
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Zu Jahr springen")
                    }
                }
            }
        }
    }

    // MARK: - Main content

    private var content: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                header

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: 22) {
                        ForEach(timelineItems) { item in
                            switch item.kind {
                            case .year(let y):
                                YearMarker(year: y)
                                    .id(scrollID(forYear: y))

                            case .book(let book, let date):
                                TimelineBookTile(book: book, date: date)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                    // The time axis line that runs behind the dots.
                    .background(alignment: .bottom) {
                        Rectangle()
                            .fill(.secondary.opacity(0.25))
                            .frame(height: 2)
                            .padding(.horizontal, 16)
                            .offset(y: -8)
                    }
                }
                .scrollTargetBehavior(.viewAligned)
                .onChange(of: jumpToYear) { _, newValue in
                    guard let y = newValue else { return }
                    withAnimation(.snappy) {
                        proxy.scrollTo(scrollID(forYear: y), anchor: .leading)
                    }
                }

                footerHint
            }
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Deine gelesenen Bücher als Zeitstrahl")
                .font(.headline)

            Text("Links fängt’s an, rechts geht’s weiter. Wenn du beim Scrollen plötzlich 2019 wieder siehst: keine Panik – das ist Nostalgie, kein Bug.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var footerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .foregroundStyle(.secondary)
            Text("Tipp: Tippe ein Cover an, um direkt ins Buch zu springen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
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

    private var timelineItems: [TimelineItem] {
        guard !timelineEntries.isEmpty else { return [] }

        var items: [TimelineItem] = []
        var lastYear: Int?

        for (book, date) in timelineEntries {
            let y = Calendar.current.component(.year, from: date)
            if lastYear != y {
                items.append(TimelineItem(kind: .year(y)))
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

// MARK: - Timeline items

private struct TimelineItem: Identifiable {
    enum Kind {
        case year(Int)
        case book(Book, Date)
    }

    let id = UUID()
    let kind: Kind
}

// MARK: - UI pieces

private struct YearMarker: View {
    let year: Int

    var body: some View {
        VStack(spacing: 10) {
            Text(String(year))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2, height: 20)

            TimelineDot()
        }
        .padding(.bottom, 2)
        .frame(width: 84)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Jahr \(year)")
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
