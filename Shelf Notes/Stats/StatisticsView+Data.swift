import Foundation

extension StatisticsView {

    // MARK: - Data plumbing

    func scopedBooks(for scope: Scope, in input: [Book]) -> [Book] {
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

    func availableYears(from input: [Book]) -> [Int] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)

        for book in input {
            if let d = readKeyDate(book) {
                years.insert(cal.component(.year, from: d))
            }
            if let y = publishedYear(from: book.publishedDate) {
                years.insert(y)
            }
        }

        return years.sorted(by: >)
    }

    func finishedBooks(in year: Int, from input: [Book]) -> [Book] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date.distantFuture

        return input.filter { book in
            guard book.status == .finished else { return false }
            guard let d = readKeyDate(book) else { return false }
            return d >= start && d < end
        }
    }

    func readKeyDate(_ book: Book) -> Date? {
        guard book.status == .finished else { return nil }
        return book.readTo ?? book.readFrom
    }

    struct MonthKey: Hashable, Identifiable {
        let year: Int
        let month: Int
        var id: String { "\(year)-\(month)" }

        var monthLabel: String {
            let cal = Calendar.current
            let d = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
            return d.formatted(.dateTime.month(.abbreviated))
        }
    }

    struct MonthSeriesPoint: Identifiable, Equatable {
        let id: String
        let monthLabel: String
        let finishedCount: Int
        let pages: Int
    }

    // MARK: - Aggregations

    func totalPages(_ input: [Book]) -> Int {
        input.reduce(0) { $0 + ($1.pageCount ?? 0) }
    }

    func uniqueAuthors(_ input: [Book]) -> Set<String> {
        var out = Set<String>()
        for b in input {
            let s = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.insert(s) }
        }
        return out
    }

    func uniquePublishers(_ input: [Book]) -> Set<String> {
        var out = Set<String>()
        for b in input {
            let s = (b.publisher ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.insert(s) }
        }
        return out
    }

    func topGenresList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]

        for b in input {
            for g in extractedGenres(from: b) {
                let n = normalizeLabel(g)
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }

        return sortedCounts(counts, limit: limit)
    }
    func topSubgenresList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]

        for b in input {
            for g in extractedSubgenres(from: b) {
                let n = normalizeLabel(g)
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }

        return sortedCounts(counts, limit: limit)
    }

    func extractedGenres(from book: Book) -> [String] {
        // „Genres“: eher die übergeordnete Kategorie (nach Entfernen von sehr generischen Präfixen).
        // Beispiel: "Fiction / Thriller" -> Genre = "Thriller"
        // Beispiel: "Fiction / Thriller / Noir" -> Genre = "Thriller"
        var out: [String] = []

        func add(_ raw: String?) {
            let parsed = parseGenre(raw)
            let g = normalizeLabel(parsed.genre)
            guard !g.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(g) == .orderedSame }) {
                out.append(g)
            }
        }

        add(book.mainCategory)
        for c in book.categories { add(c) }

        return out
    }

    func extractedSubgenres(from book: Book) -> [String] {
        // „Subgenres“: die spezifischste Stufe (Leaf) – wenn vorhanden.
        // Beispiel: "Fiction / Thriller" -> kein Subgenre
        // Beispiel: "Fiction / Thriller / Noir" -> Subgenre = "Noir"
        var out: [String] = []

        func add(_ raw: String?) {
            let parsed = parseGenre(raw)
            guard let s = parsed.subgenre else { return }
            let n = normalizeLabel(s)
            guard !n.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
                out.append(n)
            }
        }

        add(book.mainCategory)
        for c in book.categories { add(c) }

        return out
    }

    struct ParsedGenre {
        let genre: String
        let subgenre: String?
    }

    func parseGenre(_ raw: String?) -> ParsedGenre {
        let tokens = genreTokens(raw)
        guard !tokens.isEmpty else { return ParsedGenre(genre: "", subgenre: nil) }

        // 1) Kopf abschneiden (sehr generische Dinge)
        var trimmed = tokens
        while let first = trimmed.first, isGenericGenreHead(first) && trimmed.count > 1 {
            trimmed.removeFirst()
        }

        // 2) „General“ / ähnliche Enden entfernen, falls sie die Spezifität kaputt machen
        while let last = trimmed.last, isGenericGenreLeaf(last) && trimmed.count > 1 {
            trimmed.removeLast()
        }

        guard !trimmed.isEmpty else {
            return ParsedGenre(genre: tokens.first ?? "", subgenre: nil)
        }

        if trimmed.count == 1 {
            return ParsedGenre(genre: trimmed[0], subgenre: nil)
        }

        // Genre = vorletztes Element, Subgenre = letztes Element
        let genre = trimmed[trimmed.count - 2]
        let subgenre = trimmed.last

        return ParsedGenre(genre: genre, subgenre: subgenre)
    }

    func genreTokens(_ raw: String?) -> [String] {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return [] }

        // Trennzeichen normalisieren
        let replacements: [(String, String)] = [
            (">", "/"),
            ("•", "/"),
            ("|", "/"),
            ("—", "/"),
            ("–", "/"),
            (":", "/")
        ]
        for (from, to) in replacements { s = s.replacingOccurrences(of: from, with: to) }

        let parts = s
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts
    }

    func isGenericGenreHead(_ s: String) -> Bool {
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let generic: Set<String> = [
            "fiction",
            "nonfiction",
            "juvenile fiction",
            "juvenile nonfiction",
            "young adult fiction",
            "young adult",
            "general"
        ]
        return generic.contains(v)
    }

    func isGenericGenreLeaf(_ s: String) -> Bool {
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let generic: Set<String> = [
            "general",
            "miscellaneous",
            "other"
        ]
        return generic.contains(v)
    }

    func topAuthorsList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            let a = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !a.isEmpty else { continue }
            counts[a, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    func topPublishersList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            let p = (b.publisher ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty else { continue }
            counts[p, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    func topLanguagesList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            let l = (b.language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !l.isEmpty else { continue }
            counts[l, default: 0] += 1
        }
        return sortedCounts(counts, limit: limit)
    }

    func topTagsList(_ input: [Book], limit: Int) -> [(label: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in input {
            for t in b.tags {
                let n = normalizeLabel(t.replacingOccurrences(of: "#", with: ""))
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }
        return sortedCounts(counts, limit: limit)
    }

    func sortedCounts(_ counts: [String: Int], limit: Int) -> [(label: String, count: Int)] {
        let sorted = counts
            .map { (label: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
            }
        return Array(sorted.prefix(limit))
    }

    func normalizeLabel(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Nerd metrics

    func avgPagesPerBookText(for finishedBooks: [Book]) -> String {
        let arr = finishedBooks.filter { ($0.pageCount ?? 0) > 0 }
        guard !arr.isEmpty else { return "–" }
        let pages = arr.reduce(0) { $0 + ($1.pageCount ?? 0) }
        let avg = Double(pages) / Double(arr.count)
        return formatInt(Int(avg.rounded()))
    }

    func avgDaysPerBookText(for finishedBooks: [Book]) -> String {
        let durations = finishedBooks.compactMap { daysBetween($0.readFrom, $0.readTo) }
        guard !durations.isEmpty else { return "–" }
        let avg = Double(durations.reduce(0, +)) / Double(durations.count)
        return formatInt(Int(avg.rounded()))
    }

    func avgPagesPerDayText(for finishedBooks: [Book]) -> String {
        // nur wo pages + duration vorhanden
        var speeds: [Double] = []
        for b in finishedBooks {
            guard let pages = b.pageCount, pages > 0 else { continue }
            guard let days = daysBetween(b.readFrom, b.readTo), days > 0 else { continue }
            speeds.append(Double(pages) / Double(days))
        }
        guard !speeds.isEmpty else { return "–" }
        let avg = speeds.reduce(0, +) / Double(speeds.count)
        return formatInt(Int(avg.rounded()))
    }

    func daysBetween(_ from: Date?, _ to: Date?) -> Int? {
        guard let from, let to else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: to)
        let comps = cal.dateComponents([.day], from: start, to: end)
        // +1, damit "von=bis" als 1 Tag zählt (realistischer für "habe es an dem Tag gelesen")
        if let d = comps.day {
            return max(1, d + 1)
        }
        return nil
    }

    struct NerdPick: Equatable {
        let label: String
        let sortKey: Int
    }

    func fastestBook(_ finishedBooks: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in finishedBooks {
            guard let d = daysBetween(b.readFrom, b.readTo) else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let label = "\(name) • \(formatInt(d)) Tage"
            let pick = NerdPick(label: label, sortKey: d)
            if best == nil || pick.sortKey < (best?.sortKey ?? Int.max) {
                best = pick
            }
        }
        return best
    }

    func slowestBook(_ finishedBooks: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in finishedBooks {
            guard let d = daysBetween(b.readFrom, b.readTo) else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let label = "\(name) • \(formatInt(d)) Tage"
            let pick = NerdPick(label: label, sortKey: d)
            if best == nil || pick.sortKey > (best?.sortKey ?? Int.min) {
                best = pick
            }
        }
        return best
    }

    func biggestBook(_ finishedBooks: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in finishedBooks {
            let pages = b.pageCount ?? 0
            guard pages > 0 else { continue }
            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title
            let label = "\(name) • \(formatInt(pages)) Seiten"
            let pick = NerdPick(label: label, sortKey: pages)
            if best == nil || pick.sortKey > (best?.sortKey ?? 0) {
                best = pick
            }
        }
        return best
    }

    func highestRatedBook(_ input: [Book]) -> NerdPick? {
        var best: NerdPick?
        for b in input {
            let r = b.userRatingAverage1 ?? 0
            guard r > 0 else { continue }

            let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "Ohne Titel" : title

            let label = "\(name) • \(String(format: "%.1f", r)) / 5"
            let pick = NerdPick(label: label, sortKey: Int((r * 10).rounded()))

            if best == nil || pick.sortKey > (best?.sortKey ?? 0) {
                best = pick
            }
        }
        return best
    }

}
