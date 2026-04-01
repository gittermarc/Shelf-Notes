import Foundation

enum TagsIndexBuilder {

    struct TagCount: Identifiable, Hashable {
        let tag: String
        let count: Int

        var id: String { tag }
    }

    struct BookTagsSnapshot: Hashable {
        let id: UUID
        let tags: [String]
    }

    static func makeSnapshot(books: [Book]) -> [BookTagsSnapshot] {
        books.map { BookTagsSnapshot(id: $0.id, tags: $0.tags) }
    }

    static func uniqueNormalizedTags(_ tags: [String]) -> [String] {
        var out: [String] = []
        out.reserveCapacity(tags.count)

        for rawTag in tags {
            let normalized = normalizeTagString(rawTag)
            guard !normalized.isEmpty else { continue }

            if !out.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                out.append(normalized)
            }
        }

        return out
    }

    static func parsedTags(from input: String) -> [String] {
        let parts = input
            .split(separator: ",")
            .map(String.init)

        let normalizedParts = uniqueNormalizedTags(parts)
        if normalizedParts.isEmpty {
            return uniqueNormalizedTags([input])
        }

        return normalizedParts
    }

    static func toggledTag(_ tag: String, in existingTags: [String]) -> [String] {
        let normalized = normalizeTagString(tag)
        guard !normalized.isEmpty else { return uniqueNormalizedTags(existingTags) }

        var current = uniqueNormalizedTags(existingTags)
        if let index = current.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            current.remove(at: index)
            return current
        }

        current.append(normalized)
        return current
    }

    static func mergedTags(existingTags: [String], addedTags: [String]) -> [String] {
        let normalizedExisting = uniqueNormalizedTags(existingTags)
        let normalizedAdded = uniqueNormalizedTags(addedTags)

        guard !normalizedAdded.isEmpty else { return normalizedExisting }

        var out = normalizedExisting
        for tag in normalizedAdded {
            if !out.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                out.append(tag)
            }
        }

        return out
    }

    static func removingTag(_ tag: String, from existingTags: [String]) -> [String] {
        let normalized = normalizeTagString(tag)
        guard !normalized.isEmpty else { return uniqueNormalizedTags(existingTags) }

        return uniqueNormalizedTags(existingTags).filter {
            $0.caseInsensitiveCompare(normalized) != .orderedSame
        }
    }

    static func autocompleteSuggestions(
        query: String,
        selectedTags: [String],
        tagCounts: [TagCount],
        limit: Int = 8
    ) -> [String] {
        let normalizedQuery = normalizeTagString(query)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        let selected = Set(uniqueNormalizedTags(selectedTags).map { $0.lowercased() })
        let ordered = tagCounts.filter { !selected.contains($0.tag.lowercased()) }

        let prefixMatches = ordered.filter { $0.tag.lowercased().hasPrefix(normalizedQuery) }
        let fuzzyMatches = ordered.filter {
            let lowercasedTag = $0.tag.lowercased()
            return !lowercasedTag.hasPrefix(normalizedQuery)
                && isOrderedSubsequence(normalizedQuery, in: lowercasedTag)
        }

        return Array((prefixMatches + fuzzyMatches).prefix(limit)).map(\.tag)
    }

    static func taskSignature(books: [Book]) -> UInt64 {
        computeSignature(snapshot: makeSnapshot(books: books))
    }

    static func computeTagCounts(snapshot: [BookTagsSnapshot]) -> [TagCount] {
        struct Aggregate {
            var tag: String
            var count: Int
        }

        var counts: [String: Aggregate] = [:]
        counts.reserveCapacity(64)

        for book in snapshot {
            for normalized in uniqueNormalizedTags(book.tags) {
                let key = normalized.lowercased()
                if var aggregate = counts[key] {
                    aggregate.count += 1
                    counts[key] = aggregate
                } else {
                    counts[key] = Aggregate(tag: normalized, count: 1)
                }
            }
        }

        return counts
            .values
            .map { TagCount(tag: $0.tag, count: $0.count) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
            }
    }

    private static func isOrderedSubsequence(_ needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty else { return true }
        guard !haystack.isEmpty else { return false }

        var needleIndex = needle.startIndex
        var haystackIndex = haystack.startIndex

        while needleIndex < needle.endIndex, haystackIndex < haystack.endIndex {
            if needle[needleIndex] == haystack[haystackIndex] {
                needle.formIndex(after: &needleIndex)
            }
            haystack.formIndex(after: &haystackIndex)
        }

        return needleIndex == needle.endIndex
    }

    static func computeSignature(snapshot: [BookTagsSnapshot]) -> UInt64 {
        var aggregate: UInt64 = 0x9E37_79B9_7F4A_7C15
        aggregate &+= UInt64(snapshot.count) &* 0xBF58_476D_1CE4_E5B9

        for book in snapshot {
            var hasher = Hasher()
            hasher.combine(book.id)
            hasher.combine(book.tags.count)
            for rawTag in book.tags {
                let normalized = normalizeTagString(rawTag)
                guard !normalized.isEmpty else { continue }
                hasher.combine(normalized)
            }

            let h = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= h &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }

        return aggregate
    }
}