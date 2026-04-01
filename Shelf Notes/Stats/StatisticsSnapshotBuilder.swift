import Foundation

nonisolated struct StatisticsBookSnapshot: Sendable {
    nonisolated struct ReadingSessionSnapshot: Sendable {
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int
        let pagesRead: Int?

        init(startedAt: Date, endedAt: Date, durationSeconds: Int, pagesRead: Int?) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = durationSeconds
            self.pagesRead = pagesRead
        }

        @MainActor init(session: ReadingSession) {
            self.startedAt = session.startedAt
            self.endedAt = session.endedAt
            self.durationSeconds = session.durationSeconds
            self.pagesRead = session.pagesReadNormalized
        }
    }

    let title: String
    let author: String
    let statusRawValue: String
    let tags: [String]
    let readFrom: Date?
    let readTo: Date?
    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
    let language: String?
    let categories: [String]
    let subtitle: String?
    let averageRating: Double?
    let ratingsCount: Int?
    let mainCategory: String?
    let userRatingAverage1: Double?
    let readingSessions: [ReadingSessionSnapshot]

    init(
        title: String,
        author: String = "",
        statusRawValue: String = ReadingStatus.toRead.rawValue,
        tags: [String] = [],
        readFrom: Date? = nil,
        readTo: Date? = nil,
        publisher: String? = nil,
        publishedDate: String? = nil,
        pageCount: Int? = nil,
        language: String? = nil,
        categories: [String] = [],
        subtitle: String? = nil,
        averageRating: Double? = nil,
        ratingsCount: Int? = nil,
        mainCategory: String? = nil,
        userRatingAverage1: Double? = nil,
        readingSessions: [ReadingSessionSnapshot] = []
    ) {
        self.title = title
        self.author = author
        self.statusRawValue = statusRawValue
        self.tags = tags
        self.readFrom = readFrom
        self.readTo = readTo
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.pageCount = pageCount
        self.language = language
        self.categories = categories
        self.subtitle = subtitle
        self.averageRating = averageRating
        self.ratingsCount = ratingsCount
        self.mainCategory = mainCategory
        self.userRatingAverage1 = userRatingAverage1
        self.readingSessions = readingSessions
    }

    @MainActor init(book: Book) {
        self.title = book.title
        self.author = book.author
        self.statusRawValue = book.statusRawValue
        self.tags = book.tags
        self.readFrom = book.readFrom
        self.readTo = book.readTo
        self.publisher = book.publisher
        self.publishedDate = book.publishedDate
        self.pageCount = book.pageCount
        self.language = book.language
        self.categories = book.categories
        self.subtitle = book.subtitle
        self.averageRating = book.averageRating
        self.ratingsCount = book.ratingsCount
        self.mainCategory = book.mainCategory
        self.userRatingAverage1 = book.userRatingAverage1
        self.readingSessions = book.readingSessionsSafe.map(ReadingSessionSnapshot.init)
    }

    var status: ReadingStatus {
        ReadingStatus.fromPersisted(statusRawValue) ?? .toRead
    }
}

nonisolated struct StatisticsSnapshotBuilder {
    let now: Date
    let calendar: Calendar

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    func makeStatsCache(
        for key: StatisticsStatsCacheKey,
        books: [StatisticsBookSnapshot]
    ) -> StatisticsStatsCache {
        let scoped = scopedBooks(for: key.scope, in: books)
        let finishedInYear = finishedBooks(in: key.selectedYear, from: scoped)
        let summary = makeSummary(allBooks: books, scopedBooks: scoped, finishedInYear: finishedInYear)
        let months = StatisticsMonthAxisBuilder.months(for: key.selectedYear, now: now, calendar: calendar)
        let topGenres = topGenresList(scoped, limit: 8)
        let topSubgenres = topSubgenresList(scoped, limit: 8)
        let topAuthors = topAuthorsList(scoped, limit: 8)
        let topPublishers = topPublishersList(scoped, limit: 8)
        let topLanguages = topLanguagesList(scoped, limit: 8)
        let topTags = topTagsList(scoped, limit: 10)

        return StatisticsStatsCache(
            key: key,
            summary: summary,
            monthsCount: months.count,
            monthlySeries: monthlySeriesFor(months: months, finishedBooks: finishedInYear),
            topGenres: topGenres,
            topSubgenres: topSubgenres,
            topAuthors: topAuthors,
            topPublishers: topPublishers,
            topLanguages: topLanguages,
            topTags: topTags,
            fastest: fastestBook(finishedInYear),
            slowest: slowestBook(finishedInYear),
            biggest: biggestBook(finishedInYear),
            highestRated: highestRatedBook(scoped)
        )
    }
}

private nonisolated extension StatisticsSnapshotBuilder {

    func scopedBooks(
        for scope: StatisticsScope,
        in input: [StatisticsBookSnapshot]
    ) -> [StatisticsBookSnapshot] {
        switch scope {
        case .all:
            return input
        case .finished:
            return input.filter { $0.status == .finished }
        case .reading:
            return input.filter { $0.status == .reading }
        case .toRead:
            return input.filter { $0.status == .toRead }
        }
    }

    func availableYears(from input: [StatisticsBookSnapshot]) -> [Int] {
        let currentYear = calendar.component(.year, from: now)
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)

        for book in input {
            if let date = readKeyDate(book) {
                years.insert(calendar.component(.year, from: date))
            }
            if let year = publishedYear(from: book.publishedDate) {
                years.insert(year)
            }
        }

        return years.sorted(by: >)
    }

    func finishedBooks(
        in year: Int,
        from input: [StatisticsBookSnapshot]
    ) -> [StatisticsBookSnapshot] {
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? .distantFuture

        return input.filter { book in
            guard book.status == .finished else { return false }
            guard let date = readKeyDate(book) else { return false }
            return date >= start && date < end
        }
    }

    func readKeyDate(_ book: StatisticsBookSnapshot) -> Date? {
        guard book.status == .finished else { return nil }
        return book.readTo ?? book.readFrom
    }

    func totalPages(_ input: [StatisticsBookSnapshot]) -> Int {
        input.reduce(0) { $0 + ($1.pageCount ?? 0) }
    }

    func uniqueAuthors(_ input: [StatisticsBookSnapshot]) -> Set<String> {
        var out = Set<String>()
        for book in input {
            let author = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                out.insert(author)
            }
        }
        return out
    }

    func uniquePublishers(_ input: [StatisticsBookSnapshot]) -> Set<String> {
        var out = Set<String>()
        for book in input {
            let publisher = (book.publisher ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !publisher.isEmpty {
                out.insert(publisher)
            }
        }
        return out
    }

    func makeSummary(
        allBooks: [StatisticsBookSnapshot],
        scopedBooks: [StatisticsBookSnapshot],
        finishedInYear: [StatisticsBookSnapshot]
    ) -> StatisticsStatsCache.Summary {
        let scopedCount = scopedBooks.count
        let finishedScopedCount = scopedBooks.reduce(into: 0) { partial, book in
            if book.status == .finished {
                partial += 1
            }
        }
        let scopedPages = totalPages(scopedBooks)
        let uniqueAuthorsCount = uniqueAuthors(scopedBooks).count
        let uniquePublishersCount = uniquePublishers(scopedBooks).count
        let pagesInSelectedYear = totalPages(finishedInYear)
        let avgPagesPerBook = avgPagesPerBookText(for: finishedInYear)
        let avgDaysPerBook = avgDaysPerBookText(for: finishedInYear)
        let avgPagesPerDay = avgPagesPerDayText(for: finishedInYear)

        let tinyTeaserLine: String?
        if finishedInYear.count >= 2, avgPagesPerBook != "–" || avgDaysPerBook != "–" || avgPagesPerDay != "–" {
            if avgPagesPerDay == "–" && avgDaysPerBook == "–" {
                tinyTeaserLine = nil
            } else {
                tinyTeaserLine = "Ø \(avgPagesPerDay) Seiten/Tag • Ø \(avgDaysPerBook) Tage/Buch (für „Gelesen“ mit Zeitraum)"
            }
        } else {
            tinyTeaserLine = nil
        }

        return StatisticsStatsCache.Summary(
            yearOptions: availableYears(from: allBooks),
            heroSubtitle: "\(scopedCount) Bücher • \(finishedScopedCount) gelesen • \(formatInt(scopedPages)) Seiten (wo vorhanden)",
            tinyTeaserLine: tinyTeaserLine,
            overview: StatisticsStatsCache.Summary.Overview(
                scopedBooksCount: scopedCount,
                finishedScopedBooksCount: finishedScopedCount,
                uniqueAuthorsCount: uniqueAuthorsCount,
                uniquePublishersCount: uniquePublishersCount,
                pagesInSelectedYear: pagesInSelectedYear,
                finishedInSelectedYearCount: finishedInYear.count,
                avgPagesPerBookText: avgPagesPerBook,
                avgDaysPerBookText: avgDaysPerBook
            )
        )
    }

    func monthlySeriesFor(
        months: [StatisticsMonthKey],
        finishedBooks: [StatisticsBookSnapshot]
    ) -> [StatisticsMonthSeriesPoint] {
        var countBy: [StatisticsMonthKey: Int] = [:]
        var pagesBy: [StatisticsMonthKey: Int] = [:]

        for book in finishedBooks {
            guard let date = readKeyDate(book) else { continue }
            let key = StatisticsMonthKey(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date)
            )
            countBy[key, default: 0] += 1
            pagesBy[key, default: 0] += (book.pageCount ?? 0)
        }

        return months.map { month in
            StatisticsMonthSeriesPoint(
                id: month.id,
                monthLabel: monthLabel(for: month),
                finishedCount: countBy[month, default: 0],
                pages: pagesBy[month, default: 0]
            )
        }
    }

    func monthLabel(for month: StatisticsMonthKey) -> String {
        StatisticsMonthAxisBuilder.monthLabel(for: month, calendar: calendar, fallbackDate: now)
    }

    func topGenresList(_ input: [StatisticsBookSnapshot], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]

        for book in input {
            for genre in extractedGenres(from: book) {
                let normalized = normalizeLabel(genre)
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }

        return sortedCounts(counts, limit: limit)
    }

    func topSubgenresList(_ input: [StatisticsBookSnapshot], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]

        for book in input {
            for subgenre in extractedSubgenres(from: book) {
                let normalized = normalizeLabel(subgenre)
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }

        return sortedCounts(counts, limit: limit)
    }

    func extractedGenres(from book: StatisticsBookSnapshot) -> [String] {
        var out: [String] = []

        func add(_ raw: String?) {
            let parsed = parseGenre(raw)
            let genre = normalizeLabel(parsed.genre)
            guard !genre.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(genre) == .orderedSame }) {
                out.append(genre)
            }
        }

        add(book.mainCategory)
        for category in book.categories {
            add(category)
        }

        return out
    }

    func extractedSubgenres(from book: StatisticsBookSnapshot) -> [String] {
        var out: [String] = []

        func add(_ raw: String?) {
            let parsed = parseGenre(raw)
            guard let subgenre = parsed.subgenre else { return }
            let normalized = normalizeLabel(subgenre)
            guard !normalized.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                out.append(normalized)
            }
        }

        add(book.mainCategory)
        for category in book.categories {
            add(category)
        }

        return out
    }

    struct ParsedGenre {
        let genre: String
        let subgenre: String?
    }

    func parseGenre(_ raw: String?) -> ParsedGenre {
        let tokens = genreTokens(raw)
        guard !tokens.isEmpty else {
            return ParsedGenre(genre: "", subgenre: nil)
        }

        var trimmed = tokens
        while let first = trimmed.first, isGenericGenreHead(first), trimmed.count > 1 {
            trimmed.removeFirst()
        }

        while let last = trimmed.last, isGenericGenreLeaf(last), trimmed.count > 1 {
            trimmed.removeLast()
        }

        guard !trimmed.isEmpty else {
            return ParsedGenre(genre: tokens.first ?? "", subgenre: nil)
        }

        if trimmed.count == 1 {
            return ParsedGenre(genre: trimmed[0], subgenre: nil)
        }

        return ParsedGenre(
            genre: trimmed[trimmed.count - 2],
            subgenre: trimmed.last
        )
    }

    func genreTokens(_ raw: String?) -> [String] {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return []
        }

        let replacements: [(String, String)] = [
            (">", "/"),
            ("•", "/"),
            ("|", "/"),
            ("—", "/"),
            ("–", "/"),
            (":", "/")
        ]
        for (from, to) in replacements {
            value = value.replacingOccurrences(of: from, with: to)
        }

        return value
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func isGenericGenreHead(_ value: String) -> Bool {
        let generic: Set<String> = [
            "fiction",
            "nonfiction",
            "juvenile fiction",
            "juvenile nonfiction",
            "young adult fiction",
            "young adult",
            "general"
        ]
        return generic.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func isGenericGenreLeaf(_ value: String) -> Bool {
        let generic: Set<String> = [
            "general",
            "miscellaneous",
            "other"
        ]
        return generic.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func topAuthorsList(_ input: [StatisticsBookSnapshot], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for book in input {
            let author = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !author.isEmpty else { continue }
            counts[author, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    func topPublishersList(_ input: [StatisticsBookSnapshot], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for book in input {
            let publisher = (book.publisher ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !publisher.isEmpty else { continue }
            counts[publisher, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    func topLanguagesList(_ input: [StatisticsBookSnapshot], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for book in input {
            let language = (book.language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !language.isEmpty else { continue }
            counts[language, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    func topTagsList(_ input: [StatisticsBookSnapshot], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for book in input {
            for tag in book.tags {
                let normalized = normalizeLabel(tag.replacingOccurrences(of: "#", with: ""))
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }
        return sortedCounts(counts, limit: limit)
    }

    func sortedCounts(_ counts: [String: Int], limit: Int) -> [(label: String, count: Int)] {
        let sorted = counts
            .map { (label: $0.key, count: $0.value) }
            .sorted { left, right in
                if left.count != right.count {
                    return left.count > right.count
                }
                return left.label.localizedCaseInsensitiveCompare(right.label) == .orderedAscending
            }
        return Array(sorted.prefix(limit))
    }

    func normalizeLabel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func avgPagesPerBookText(for finishedBooks: [StatisticsBookSnapshot]) -> String {
        let withPages = finishedBooks.filter { ($0.pageCount ?? 0) > 0 }
        guard !withPages.isEmpty else { return "–" }
        let pages = withPages.reduce(0) { $0 + ($1.pageCount ?? 0) }
        let average = Double(pages) / Double(withPages.count)
        return formatInt(Int(average.rounded()))
    }

    func avgDaysPerBookText(for finishedBooks: [StatisticsBookSnapshot]) -> String {
        let durations = finishedBooks.compactMap { daysBetween($0.readFrom, $0.readTo) }
        guard !durations.isEmpty else { return "–" }
        let average = Double(durations.reduce(0, +)) / Double(durations.count)
        return formatInt(Int(average.rounded()))
    }

    func avgPagesPerDayText(for finishedBooks: [StatisticsBookSnapshot]) -> String {
        var speeds: [Double] = []
        for book in finishedBooks {
            guard let pages = book.pageCount, pages > 0 else { continue }
            guard let days = daysBetween(book.readFrom, book.readTo), days > 0 else { continue }
            speeds.append(Double(pages) / Double(days))
        }
        guard !speeds.isEmpty else { return "–" }
        let average = speeds.reduce(0, +) / Double(speeds.count)
        return formatInt(Int(average.rounded()))
    }

    func daysBetween(_ from: Date?, _ to: Date?) -> Int? {
        guard let from, let to else { return nil }
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        let components = calendar.dateComponents([.day], from: start, to: end)
        if let days = components.day {
            return max(1, days + 1)
        }
        return nil
    }

    func fastestBook(_ finishedBooks: [StatisticsBookSnapshot]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for book in finishedBooks {
            guard let days = daysBetween(book.readFrom, book.readTo) else { continue }
            let name = normalizedTitle(for: book)
            let pick = StatisticsNerdPick(
                label: "\(name) • \(formatInt(days)) Tage",
                sortKey: days
            )
            if best == nil || pick.sortKey < (best?.sortKey ?? .max) {
                best = pick
            }
        }
        return best
    }

    func slowestBook(_ finishedBooks: [StatisticsBookSnapshot]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for book in finishedBooks {
            guard let days = daysBetween(book.readFrom, book.readTo) else { continue }
            let name = normalizedTitle(for: book)
            let pick = StatisticsNerdPick(
                label: "\(name) • \(formatInt(days)) Tage",
                sortKey: days
            )
            if best == nil || pick.sortKey > (best?.sortKey ?? .min) {
                best = pick
            }
        }
        return best
    }

    func biggestBook(_ finishedBooks: [StatisticsBookSnapshot]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for book in finishedBooks {
            let pages = book.pageCount ?? 0
            guard pages > 0 else { continue }
            let name = normalizedTitle(for: book)
            let pick = StatisticsNerdPick(
                label: "\(name) • \(formatInt(pages)) Seiten",
                sortKey: pages
            )
            if best == nil || pick.sortKey > (best?.sortKey ?? 0) {
                best = pick
            }
        }
        return best
    }

    func highestRatedBook(_ input: [StatisticsBookSnapshot]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for book in input {
            let rating = book.userRatingAverage1 ?? 0
            guard rating > 0 else { continue }
            let name = normalizedTitle(for: book)
            let pick = StatisticsNerdPick(
                label: "\(name) • \(String(format: "%.1f", rating)) / 5",
                sortKey: Int((rating * 10).rounded())
            )
            if best == nil || pick.sortKey > (best?.sortKey ?? 0) {
                best = pick
            }
        }
        return best
    }

    func normalizedTitle(for book: StatisticsBookSnapshot) -> String {
        let title = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Ohne Titel" : title
    }

    func publishedYear(from raw: String?) -> Int? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let digits = raw.prefix(4).filter(\.isNumber)
        guard digits.count == 4, let year = Int(digits) else { return nil }
        return year
    }

    func formatInt(_ value: Int) -> String {
        value.formatted(
            .number
                .grouping(.automatic)
                .locale(Locale(identifier: "de_DE"))
        )
    }
}
