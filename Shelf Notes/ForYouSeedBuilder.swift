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
enum ForYouSeedBuilder {

    /// Returns a curated list of seeds, ordered by relevance.
    ///
    /// Strategy (cheap but effective):
    /// - Consider only books the user is currently reading or has finished.
    /// - Derive top categories and top authors.
    /// - Translate them into Google Books query strings (`subject:` / `inauthor:`).
    /// - If we don't have enough signal, fall back to a small set of generic seeds.
    static func build(from books: [Book]) -> [InspirationSeed] {
        // 1) pick the "signal" books
        let signalBooks: [Book] = books.filter {
            let status = ReadingStatus.fromPersisted($0.statusRawValue) ?? .toRead
            return status == .reading || status == .finished
        }

        // 2) collect weighted counts
        var categoryCounts: [String: Int] = [:]
        var authorCounts: [String: Int] = [:]

        for b in signalBooks {
            let status = ReadingStatus.fromPersisted(b.statusRawValue) ?? .toRead
            let weight = (status == .finished) ? 3 : 2

            // Categories
            for raw in b.categories {
                guard let cleaned = cleanCategory(raw) else { continue }
                categoryCounts[cleaned, default: 0] += weight
            }

            // Author
            if let a = cleanAuthor(b.author) {
                authorCounts[a, default: 0] += weight
            }
        }

        // 3) choose top items
        let topCategories: [String] = topKeys(in: categoryCounts, limit: 4)
        let topAuthors: [String] = topKeys(in: authorCounts, limit: 2)

        var out: [InspirationSeed] = []

        for cat in topCategories {
            out.append(
                InspirationSeed(
                    title: cat,
                    subtitle: "Weil du das liest",
                    systemImage: "tag.fill",
                    query: subjectQuery(cat)
                )
            )
        }

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

        // 4) Ensure we always return something (cold start / low signal)
        if out.isEmpty {
            out = fallbackSeeds
        } else if out.count < 4 {
            // Add a little "variety" so the card doesn't look empty
            out.append(contentsOf: fallbackSeeds.prefix(4 - out.count))
        }

        // 5) De-dupe by query (defensive)
        var seen: Set<String> = []
        return out.filter { seed in
            let key = seed.query.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Helpers

    private static func topKeys(in counts: [String: Int], limit: Int) -> [String] {
        counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            .prefix(limit)
            .map { $0.key }
    }

    /// Cleans up category strings that often look like "Fiction / Mystery & Detective / General".
    /// Returns a compact, human-friendly category title.
    private static func cleanCategory(_ raw: String) -> String? {
        let t0 = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t0.isEmpty else { return nil }

        // Split hierarchical categories and pick the most specific part.
        let parts = t0
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidate = (parts.last ?? t0)

        // Avoid ultra generic values.
        let lower = candidate.lowercased()
        if lower == "fiction" || lower == "nonfiction" || lower == "general" { return nil }

        // Normalize some common Google category noise.
        let cleaned = candidate
            .replacingOccurrences(of: "&", with: "und")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count >= 3 else { return nil }
        return cleaned
    }

    /// Picks a reasonably stable author name.
    /// - If multiple authors are stored, we pick the first one.
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

    private static func subjectQuery(_ subject: String) -> String {
        let t = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        if t.contains(" ") {
            return "subject:\"\(t)\""
        }
        return "subject:\(t)"
    }

    private static func authorQuery(_ author: String) -> String {
        let t = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        // Author names almost always contain spaces.
        return "inauthor:\"\(t)\""
    }

    private static var fallbackSeeds: [InspirationSeed] {
        [
            .init(title: "Thriller", subtitle: "Start-Idee", systemImage: "bolt.fill", query: "subject:thriller"),
            .init(title: "Fantasy", subtitle: "Start-Idee", systemImage: "wand.and.stars", query: "subject:fantasy"),
            .init(title: "Biografien", subtitle: "Start-Idee", systemImage: "person.text.rectangle", query: "subject:biography"),
            .init(title: "True Crime", subtitle: "Start-Idee", systemImage: "handcuffs", query: "\"true crime\""),
        ]
    }
}
