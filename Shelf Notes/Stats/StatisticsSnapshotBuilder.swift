import Foundation

nonisolated struct StatisticsReadingSessionSnapshot: Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let pagesRead: Int?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        pagesRead: Int?,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.pagesRead = pagesRead
        self.createdAt = createdAt ?? startedAt
    }

    @MainActor init(session: ReadingSession) {
        self.id = session.id
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.durationSeconds = session.durationSeconds
        self.pagesRead = session.pagesReadNormalized
        self.createdAt = session.createdAt
    }
}

nonisolated struct StatisticsBookSnapshot: Sendable {
    typealias ReadingSessionSnapshot = StatisticsReadingSessionSnapshot

    let id: UUID
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
    let readingCompletions: [ReadingCompletionRecord]
    let activeAttemptStartedAt: Date?

    init(
        id: UUID = UUID(),
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
        readingSessions: [ReadingSessionSnapshot] = [],
        readingCompletions: [ReadingCompletionRecord]? = nil,
        activeAttemptStartedAt: Date? = nil
    ) {
        self.id = id
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
        self.readingCompletions = readingCompletions ?? StatisticsBookSnapshot.legacyCompletions(
            id: id,
            title: title,
            author: author,
            statusRawValue: statusRawValue,
            readFrom: readFrom,
            readTo: readTo,
            pageCount: pageCount
        )
        self.activeAttemptStartedAt = activeAttemptStartedAt
    }

    @MainActor init(book: Book, includeReadingSessions: Bool = false) {
        self.id = book.id
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
        self.readingSessions = includeReadingSessions
            ? book.readingSessionsSafe.map { ReadingSessionSnapshot(session: $0) }
            : []
        self.readingCompletions = ReadingCompletionRecordBuilder.records(from: book)
        self.activeAttemptStartedAt = book.activeReadingAttempt?.startedAt
    }

    var status: ReadingStatus {
        ReadingStatus.fromPersisted(statusRawValue) ?? .toRead
    }

    var hasCompletedReading: Bool {
        !readingCompletions.isEmpty
    }

    private static func legacyCompletions(
        id: UUID,
        title: String,
        author: String,
        statusRawValue: String,
        readFrom: Date?,
        readTo: Date?,
        pageCount: Int?
    ) -> [ReadingCompletionRecord] {
        guard let record = ReadingCompletionRecord.legacyRecord(
            bookID: id,
            title: title,
            author: author,
            createdAt: readFrom ?? readTo ?? .distantPast,
            statusRawValue: statusRawValue,
            readFrom: readFrom,
            readTo: readTo,
            pageCount: pageCount
        ) else {
            return []
        }
        return [record]
    }
}

nonisolated struct StatisticsSessionBookSnapshot: Sendable {
    let bookID: UUID?
    let statusRawValue: String
    let hasCompletedReading: Bool
    let readingSessions: [StatisticsReadingSessionSnapshot]

    init(
        bookID: UUID? = nil,
        statusRawValue: String,
        hasCompletedReading: Bool = false,
        readingSessions: [StatisticsReadingSessionSnapshot]
    ) {
        self.bookID = bookID
        self.statusRawValue = statusRawValue
        self.hasCompletedReading = hasCompletedReading
        self.readingSessions = readingSessions
    }

    init(bookSnapshot: StatisticsBookSnapshot) {
        self.bookID = bookSnapshot.id
        self.statusRawValue = bookSnapshot.statusRawValue
        self.hasCompletedReading = bookSnapshot.hasCompletedReading
        self.readingSessions = bookSnapshot.readingSessions
    }

    @MainActor init(book: Book) {
        self.bookID = book.id
        self.statusRawValue = book.statusRawValue
        self.hasCompletedReading = book.completedReadingAttemptCount > 0
        self.readingSessions = book.readingSessionsSafe.map { StatisticsReadingSessionSnapshot(session: $0) }
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
        let completionsInYear = completedReadings(in: key.selectedYear, from: scoped)
        let summary = makeSummary(allBooks: books, scopedBooks: scoped, completionsInYear: completionsInYear)
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
            monthlySeries: monthlySeriesFor(months: months, completions: completionsInYear),
            topGenres: topGenres,
            topSubgenres: topSubgenres,
            topAuthors: topAuthors,
            topPublishers: topPublishers,
            topLanguages: topLanguages,
            topTags: topTags,
            fastest: fastestCompletion(completionsInYear),
            slowest: slowestCompletion(completionsInYear),
            biggest: biggestCompletion(completionsInYear),
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
            return input.filter { $0.status == .finished || $0.hasCompletedReading }
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
            for completion in book.readingCompletions {
                years.insert(calendar.component(.year, from: completion.finishedAt))
            }
            if let year = publishedYear(from: book.publishedDate) {
                years.insert(year)
            }
        }

        return years.sorted(by: >)
    }

    func completedReadings(
        in year: Int,
        from input: [StatisticsBookSnapshot]
    ) -> [ReadingCompletionRecord] {
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? .distantFuture

        return input
            .flatMap(\.readingCompletions)
            .filter { completion in
                completion.finishedAt >= start && completion.finishedAt < end
            }
            .sorted(by: ReadingCompletionRecordBuilder.compare)
    }

    func totalPages(_ input: [StatisticsBookSnapshot]) -> Int {
        input.reduce(0) { $0 + ($1.pageCount ?? 0) }
    }

    func totalPages(_ completions: [ReadingCompletionRecord]) -> Int {
        completions.reduce(0) { $0 + $1.normalizedPageCount }
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
        completionsInYear: [ReadingCompletionRecord]
    ) -> StatisticsStatsCache.Summary {
        let scopedCount = scopedBooks.count
        let scopedCompletions = scopedBooks.flatMap(\.readingCompletions)
        let completionCount = scopedCompletions.count
        let finishedScopedCount = Set(scopedCompletions.map(\.bookID)).count
        let rereadCount = scopedCompletions.filter(\.isReread).count
        let scopedPages = totalPages(scopedBooks)
        let uniqueAuthorsCount = uniqueAuthors(scopedBooks).count
        let uniquePublishersCount = uniquePublishers(scopedBooks).count
        let pagesInSelectedYear = totalPages(completionsInYear)
        let uniqueBooksInSelectedYear = Set(completionsInYear.map(\.bookID)).count
        let rereadsInSelectedYear = completionsInYear.filter(\.isReread).count
        let avgPagesPerBook = avgPagesPerCompletionText(for: completionsInYear)
        let avgDaysPerBook = avgDaysPerCompletionText(for: completionsInYear)
        let avgPagesPerDay = avgPagesPerDayText(for: completionsInYear)

        let tinyTeaserLine: String?
        if completionsInYear.count >= 2, avgPagesPerBook != "–" || avgDaysPerBook != "–" || avgPagesPerDay != "–" {
            if avgPagesPerDay == "–" && avgDaysPerBook == "–" {
                tinyTeaserLine = nil
            } else {
                tinyTeaserLine = "Ø \(avgPagesPerDay) Seiten/Tag • Ø \(avgDaysPerBook) Tage/Abschluss"
            }
        } else {
            tinyTeaserLine = nil
        }

        let progressText: String
        if completionCount == finishedScopedCount {
            progressText = "\(finishedScopedCount) gelesen"
        } else {
            progressText = "\(completionCount) Abschlüsse • \(finishedScopedCount) Bücher gelesen"
        }

        return StatisticsStatsCache.Summary(
            yearOptions: availableYears(from: allBooks),
            heroSubtitle: "\(scopedCount) Bücher • \(progressText) • \(formatInt(scopedPages)) Seiten (wo vorhanden)",
            tinyTeaserLine: tinyTeaserLine,
            overview: StatisticsStatsCache.Summary.Overview(
                scopedBooksCount: scopedCount,
                finishedScopedBooksCount: finishedScopedCount,
                readingCompletionCount: completionCount,
                rereadCompletionCount: rereadCount,
                uniqueAuthorsCount: uniqueAuthorsCount,
                uniquePublishersCount: uniquePublishersCount,
                pagesInSelectedYear: pagesInSelectedYear,
                finishedInSelectedYearCount: completionsInYear.count,
                uniqueBooksInSelectedYearCount: uniqueBooksInSelectedYear,
                rereadCompletionsInSelectedYearCount: rereadsInSelectedYear,
                avgPagesPerBookText: avgPagesPerBook,
                avgDaysPerBookText: avgDaysPerBook
            )
        )
    }

    func monthlySeriesFor(
        months: [StatisticsMonthKey],
        completions: [ReadingCompletionRecord]
    ) -> [StatisticsMonthSeriesPoint] {
        var countBy: [StatisticsMonthKey: Int] = [:]
        var pagesBy: [StatisticsMonthKey: Int] = [:]

        for completion in completions {
            let date = completion.finishedAt
            let key = StatisticsMonthKey(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date)
            )
            countBy[key, default: 0] += 1
            pagesBy[key, default: 0] += completion.normalizedPageCount
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
                let normalized = normalizeTagString(tag)
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

    func avgPagesPerCompletionText(for completions: [ReadingCompletionRecord]) -> String {
        let withPages = completions.filter { $0.normalizedPageCount > 0 }
        guard !withPages.isEmpty else { return "–" }
        let pages = withPages.reduce(0) { $0 + $1.normalizedPageCount }
        let average = Double(pages) / Double(withPages.count)
        return formatInt(Int(average.rounded()))
    }

    func avgDaysPerCompletionText(for completions: [ReadingCompletionRecord]) -> String {
        let durations = completions.compactMap { daysBetween($0.startedAt, $0.finishedAt) }
        guard !durations.isEmpty else { return "–" }
        let average = Double(durations.reduce(0, +)) / Double(durations.count)
        return formatInt(Int(average.rounded()))
    }

    func avgPagesPerDayText(for completions: [ReadingCompletionRecord]) -> String {
        var speeds: [Double] = []
        for completion in completions {
            let pages = completion.normalizedPageCount
            guard pages > 0 else { continue }
            guard let days = daysBetween(completion.startedAt, completion.finishedAt), days > 0 else { continue }
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

    func fastestCompletion(_ completions: [ReadingCompletionRecord]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for completion in completions {
            guard let days = daysBetween(completion.startedAt, completion.finishedAt) else { continue }
            let name = normalizedTitle(for: completion)
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

    func slowestCompletion(_ completions: [ReadingCompletionRecord]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for completion in completions {
            guard let days = daysBetween(completion.startedAt, completion.finishedAt) else { continue }
            let name = normalizedTitle(for: completion)
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

    func biggestCompletion(_ completions: [ReadingCompletionRecord]) -> StatisticsNerdPick? {
        var best: StatisticsNerdPick?
        for completion in completions {
            let pages = completion.normalizedPageCount
            guard pages > 0 else { continue }
            let name = normalizedTitle(for: completion)
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

    func normalizedTitle(for completion: ReadingCompletionRecord) -> String {
        let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
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
