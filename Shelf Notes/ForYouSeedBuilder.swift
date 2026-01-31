//
//  ForYouSeedBuilder.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 30.01.26.
//

import Foundation

/// Builds "Für dich" inspiration seeds based on the user's existing library.
///
/// Goal: feel personalized without requiring any new backend or heavy data model changes.
/// "Mehr Magie ohne Aufwand" happens mainly by:
/// - splitting combined categories ("Business & Economics", "Biography und Autobiografie") into usable tokens
/// - normalizing synonyms (DE/EN) so counts don't fragment
/// - creating a couple of "Kombi"-seeds (Autor + Thema)
enum ForYouSeedBuilder {

    // MARK: - Public

    static func build(from books: [Book]) -> [InspirationSeed] {
        // 1) pick the "signal" books
        let signalBooks: [Book] = books.filter {
            let status = ReadingStatus.fromPersisted($0.statusRawValue) ?? .toRead
            return status == .reading || status == .finished
        }

        // 2) collect weighted counts
        var categoryCounts: [CategoryProfile: Int] = [:]
        var authorCounts: [String: Int] = [:]

        for b in signalBooks {
            let status = ReadingStatus.fromPersisted(b.statusRawValue) ?? .toRead
            let weight = (status == .finished) ? 3 : 2

            // Categories
            for raw in b.categories {
                for token in extractCategoryTokens(raw) {
                    guard let profile = normalizeCategory(token) else { continue }
                    categoryCounts[profile, default: 0] += weight
                }
            }

            // Author
            if let a = cleanAuthor(b.author) {
                authorCounts[a, default: 0] += weight
            }
        }

        let topCategories: [CategoryProfile] = topKeys(in: categoryCounts, limit: 4)
        let topAuthors: [String] = topKeys(in: authorCounts, limit: 2)

        var out: [InspirationSeed] = []

        // ✅ "Mehr Magie": 1–2 Kombis (Autor + Thema)
        if let bestAuthor = topAuthors.first {
            for cat in topCategories.prefix(2) {
                out.append(
                    InspirationSeed(
                        title: shortAuthor(bestAuthor) + " + " + cat.display,
                        subtitle: "Kombi: Autor & Thema",
                        systemImage: "sparkles",
                        query: comboQuery(author: bestAuthor, category: cat)
                    )
                )
            }
        }

        // ✅ "Mehr Magie": Mix aus den Top-2 Themen (breit, funktioniert auch bei unsauberen Subjects)
        if topCategories.count >= 2 {
            let a = topCategories[0].broadQueryTerm
            let b = topCategories[1].broadQueryTerm
            out.append(
                InspirationSeed(
                    title: "\(topCategories[0].display) oder \(topCategories[1].display)",
                    subtitle: "Mix deiner Themen",
                    systemImage: "wand.and.stars",
                    query: "\(a) OR \(b)"
                )
            )
        }

        // Standard: Kategorie-Seeds
        for cat in topCategories {
            out.append(
                InspirationSeed(
                    title: cat.display,
                    subtitle: "Weil du das liest",
                    systemImage: "tag.fill",
                    query: cat.query
                )
            )
        }

        // Standard: Autor-Seeds
        for author in topAuthors {
            out.append(
                InspirationSeed(
                    title: author,
                    subtitle: "Mehr von diesem Autor",
                    systemImage: "person.fill",
                    query: authorQuery(author)
                )
            )
        }

        // Cold start / low signal
        if out.isEmpty {
            out = fallbackSeeds
        } else if out.count < 6 {
            out.append(contentsOf: fallbackSeeds.prefix(6 - out.count))
        }

        // De-dupe by query (defensive)
        var seen: Set<String> = []
        return out.filter { seed in
            let key = seed.query.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Category Profile

    /// Represents a normalized category token.
    /// `key` is used for counting/unifying, `display` for UI, `query` for Google Books.
    struct CategoryProfile: Hashable {
        let key: String
        let display: String
        let query: String

        /// A broad term that works even if Google subject taxonomy doesn't match (used for Mix/OR).
        let broadQueryTerm: String
    }

    // MARK: - Token extraction & normalization

    /// Extracts usable category tokens from Google Books category strings.
    /// Examples:
    /// - "Business & Economics / General" → ["Business", "Economics"]
    /// - "Biography und Autobiografie" → ["Biography", "Autobiografie"]
    /// - "Fiction / Mystery & Detective / General" → ["Mystery", "Detective"]
    private static func extractCategoryTokens(_ raw: String) -> [String] {
        let t0 = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t0.isEmpty else { return [] }

        // Split hierarchy
        let parts = t0
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Drop ultra generic parts
        let filtered = parts.filter { part in
            let lower = part.lowercased()
            return lower != "general" && lower != "fiction" && lower != "nonfiction"
        }

        // Split connectors inside each part (Business & Economics, Biography und Autobiografie, Mystery & Detective)
        var tokens: [String] = []
        for part in filtered.isEmpty ? [t0] : filtered {
            tokens.append(contentsOf: splitConnectors(part))
        }

        // Final cleanup + drop short noise
        return tokens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }

    private static func splitConnectors(_ s: String) -> [String] {
        let normalized = " " + s + " "

        // Replace common connectors with a delimiter
        let connectors = [
            " & ", "&",
            " und ", " and ",
            " + ", "+",
            " , ", ",",
            " · ", "•"
        ]

        var work = normalized
        for c in connectors {
            work = work.replacingOccurrences(of: c, with: " | ")
        }

        return work
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Normalizes tokens across DE/EN and builds a query that actually returns results.
    ///
    /// Key detail: for "unknown" categories we do **not** force `subject:"..."` because that can easily yield 0 hits.
    /// We fall back to a broad free-text query term.
    private static func normalizeCategory(_ token: String) -> CategoryProfile? {
        let raw = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        // Remove diacritics for matching (Ökonomie, Autobiografie, ...)
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cleaned = folded
            .replacingOccurrences(of: "&", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = cleaned.lowercased()

        // Map common categories to a stable key + reliable Google query
        if let mapped = categoryMap[lower] {
            return mapped
        }

        // Broad fallback term (letters/numbers/spaces only)
        let broad = broadTextTerm(from: raw)
        guard broad.count >= 3 else { return nil }

        // Use broad free text query (works even when subject taxonomy doesn't match).
        let display = prettify(raw)
        return CategoryProfile(
            key: "free:\(broad.lowercased())",
            display: display,
            query: broad,
            broadQueryTerm: broad
        )
    }

    private static var categoryMap: [String: CategoryProfile] {
        [
            // Biografie
            "biography": CategoryProfile(key: "biography", display: "Biografien", query: "subject:biography", broadQueryTerm: "biography"),
            "biografien": CategoryProfile(key: "biography", display: "Biografien", query: "subject:biography", broadQueryTerm: "biography"),
            "biografie": CategoryProfile(key: "biography", display: "Biografien", query: "subject:biography", broadQueryTerm: "biography"),

            // Autobiografie
            "autobiography": CategoryProfile(key: "autobiography", display: "Autobiografien", query: "subject:autobiography", broadQueryTerm: "autobiography"),
            "autobiografien": CategoryProfile(key: "autobiography", display: "Autobiografien", query: "subject:autobiography", broadQueryTerm: "autobiography"),
            "autobiografie": CategoryProfile(key: "autobiography", display: "Autobiografien", query: "subject:autobiography", broadQueryTerm: "autobiography"),

            // Business / Economics
            "business": CategoryProfile(key: "business", display: "Business", query: "subject:business", broadQueryTerm: "business"),
            "wirtschaft": CategoryProfile(key: "business", display: "Business", query: "subject:business", broadQueryTerm: "business"),
            "economics": CategoryProfile(key: "economics", display: "Economics", query: "subject:economics", broadQueryTerm: "economics"),
            "okonomie": CategoryProfile(key: "economics", display: "Economics", query: "subject:economics", broadQueryTerm: "economics"),
            "ökonomie": CategoryProfile(key: "economics", display: "Economics", query: "subject:economics", broadQueryTerm: "economics"),
            "volkswirtschaft": CategoryProfile(key: "economics", display: "Economics", query: "subject:economics", broadQueryTerm: "economics"),

            // Weitere häufige
            "psychology": CategoryProfile(key: "psychology", display: "Psychologie", query: "subject:psychology", broadQueryTerm: "psychology"),
            "psychologie": CategoryProfile(key: "psychology", display: "Psychologie", query: "subject:psychology", broadQueryTerm: "psychology"),
            "history": CategoryProfile(key: "history", display: "Geschichte", query: "subject:history", broadQueryTerm: "history"),
            "geschichte": CategoryProfile(key: "history", display: "Geschichte", query: "subject:history", broadQueryTerm: "history"),

            "thriller": CategoryProfile(key: "thriller", display: "Thriller", query: "subject:thriller", broadQueryTerm: "thriller"),
            "crime": CategoryProfile(key: "crime", display: "Krimi", query: "subject:crime", broadQueryTerm: "crime"),
            "krimi": CategoryProfile(key: "crime", display: "Krimi", query: "subject:crime", broadQueryTerm: "crime"),
            "fantasy": CategoryProfile(key: "fantasy", display: "Fantasy", query: "subject:fantasy", broadQueryTerm: "fantasy"),
            "horror": CategoryProfile(key: "horror", display: "Horror", query: "subject:horror", broadQueryTerm: "horror"),
            "romance": CategoryProfile(key: "romance", display: "Romance", query: "subject:romance", broadQueryTerm: "romance"),
            "science fiction": CategoryProfile(key: "science fiction", display: "Sci-Fi", query: #"subject:"science fiction""#, broadQueryTerm: "science fiction"),
            "sci fi": CategoryProfile(key: "science fiction", display: "Sci-Fi", query: #"subject:"science fiction""#, broadQueryTerm: "science fiction"),
            "scifi": CategoryProfile(key: "science fiction", display: "Sci-Fi", query: #"subject:"science fiction""#, broadQueryTerm: "science fiction"),
            "true crime": CategoryProfile(key: "true crime", display: "True Crime", query: #""true crime""#, broadQueryTerm: "true crime"),
        ]
    }

    private static func broadTextTerm(from raw: String) -> String {
        // Keep letters/numbers/spaces only
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let s = String(scalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }

    private static func prettify(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return s }
        if t.contains(where: { $0.isUppercase }) { return t }
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    // MARK: - Authors & Queries

    private static func cleanAuthor(_ raw: String) -> String? {
        let t0 = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t0.isEmpty else { return nil }

        // Handle common multi-author formats.
        let separators: [String] = [",", "&", " und ", ";"]
        var first = t0
        for sep in separators {
            if let idx = first.range(of: sep) {
                first = String(first[..<idx.lowerBound])
                break
            }
        }

        let cleaned = first.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return nil }
        return cleaned
    }

    private static func authorQuery(_ author: String) -> String {
        let t = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return #"inauthor:"\#(t)""#
    }

    private static func comboQuery(author: String, category: CategoryProfile) -> String {
        // If category.query is a subject-filter, keep it. Otherwise use broad text.
        if category.query.lowercased().hasPrefix("subject:") {
            return "\(authorQuery(author)) \(category.query)"
        } else {
            return "\(authorQuery(author)) \(category.broadQueryTerm)"
        }
    }

    private static func shortAuthor(_ author: String) -> String {
        // Avoid super long titles in tiles
        if author.count <= 16 { return author }
        let parts = author.split(separator: " ")
        if let last = parts.last, last.count >= 3 {
            return String(last)
        }
        return String(author.prefix(16)) + "…"
    }

    // MARK: - Sorting

    private static func topKeys<T: Hashable>(in counts: [T: Int], limit: Int) -> [T] {
        counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return String(describing: lhs.key).localizedCaseInsensitiveCompare(String(describing: rhs.key)) == .orderedAscending
            }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Fallback

    private static var fallbackSeeds: [InspirationSeed] {
        [
            .init(title: "Thriller", subtitle: "Start-Idee", systemImage: "bolt.fill", query: "subject:thriller"),
            .init(title: "Fantasy", subtitle: "Start-Idee", systemImage: "wand.and.stars", query: "subject:fantasy"),
            .init(title: "Biografien", subtitle: "Start-Idee", systemImage: "person.text.rectangle", query: "subject:biography"),
            .init(title: "True Crime", subtitle: "Start-Idee", systemImage: "handcuffs", query: #""true crime""#),
        ]
    }
}
