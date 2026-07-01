import Foundation

nonisolated enum TagSuggestionEngine {

    private struct ExistingTagAggregate {
        var tag: String
        var count: Int
    }

    private struct SuggestionAggregate {
        var tag: String
        var score: Int = 0
        var reasons: Set<TagSuggestionReason> = []
        var relatedBookIDs: Set<UUID> = []
        var existingTagCount: Int = 0
    }

    private enum Score {
        static let category = 90
        static let coTag = 70
        static let coTagOverlapBonus = 10
        static let similarBookUnit = 34
        static let frequentUnit = 9
        static let frequentMaximum = 54
    }

    @MainActor
    static func makeSnapshots(books: [Book]) -> [TagSuggestionBookSnapshot] {
        books.map { makeSnapshot(book: $0) }
    }

    @MainActor
    static func makeSnapshot(book: Book) -> TagSuggestionBookSnapshot {
        TagSuggestionBookSnapshot(
            id: book.id,
            title: book.title,
            author: book.author,
            tags: book.tags,
            categories: book.categories,
            mainCategory: book.mainCategory,
            statusRawValue: book.statusRawValue
        )
    }

    static func suggestions(
        for targetBook: TagSuggestionBookSnapshot,
        in library: [TagSuggestionBookSnapshot],
        limit: Int = 10
    ) -> [TagSuggestion] {
        suggestions(
            for: targetBook,
            in: TagsDomainIndex(suggestionSnapshots: library),
            limit: limit
        )
    }

    static func suggestions(
        for targetBook: TagSuggestionBookSnapshot,
        in index: TagsDomainIndex,
        limit: Int = 10
    ) -> [TagSuggestion] {
        guard limit > 0 else { return [] }

        let selectedTagKeys = Set(uniqueNormalizedTags(targetBook.tags).map { suggestionKey($0) })
        let existingTagAggregates = existingTagCounts(in: index)
        var aggregates: [String: SuggestionAggregate] = [:]

        for candidate in categoryCandidates(for: targetBook) {
            addCandidate(
                candidate,
                reason: .category,
                score: Score.category,
                relatedBookID: nil,
                selectedTagKeys: selectedTagKeys,
                existingTagAggregates: existingTagAggregates,
                aggregates: &aggregates
            )
        }

        for aggregate in existingTagAggregates.values {
            let score = min(Score.frequentMaximum, aggregate.count * Score.frequentUnit)
            addCandidate(
                aggregate.tag,
                reason: .frequent,
                score: score,
                relatedBookID: nil,
                selectedTagKeys: selectedTagKeys,
                existingTagAggregates: existingTagAggregates,
                existingTagCount: aggregate.count,
                aggregates: &aggregates
            )
        }

        addCoTagSuggestions(
            for: targetBook,
            in: index,
            selectedTagKeys: selectedTagKeys,
            existingTagAggregates: existingTagAggregates,
            aggregates: &aggregates
        )

        addSimilarBookSuggestions(
            for: targetBook,
            in: index,
            selectedTagKeys: selectedTagKeys,
            existingTagAggregates: existingTagAggregates,
            aggregates: &aggregates
        )

        return aggregates.values
            .map { aggregate in
                TagSuggestion(
                    tag: aggregate.tag,
                    score: aggregate.score,
                    reasons: orderedReasons(from: aggregate.reasons),
                    relatedBookCount: aggregate.relatedBookIDs.count,
                    existingTagCount: aggregate.existingTagCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                if lhs.existingTagCount != rhs.existingTagCount {
                    return lhs.existingTagCount > rhs.existingTagCount
                }

                if lhs.relatedBookCount != rhs.relatedBookCount {
                    return lhs.relatedBookCount > rhs.relatedBookCount
                }

                return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    static func categoryCandidates(for snapshot: TagSuggestionBookSnapshot) -> [String] {
        categoryCandidates(categories: snapshot.categories, mainCategory: snapshot.mainCategory)
    }

    static func categoryCandidates(categories: [String], mainCategory: String?) -> [String] {
        var rawValues: [String] = []

        if let mainCategory {
            rawValues.append(mainCategory)
        }
        rawValues.append(contentsOf: categories)

        var candidates: [String] = []
        for rawValue in rawValues {
            let profiles = BookImportCategoryNormalizer.profiles(from: rawValue)
            for profile in profiles {
                candidates.append(profile.display)
            }

            for hashToken in fallbackCategoryTokens(from: rawValue) where hashToken.contains("#") {
                candidates.append(hashToken)
            }

            if profiles.isEmpty {
                candidates.append(contentsOf: fallbackCategoryTokens(from: rawValue))
            }
        }

        return uniqueNormalizedTags(candidates).filter { isUsefulCategoryCandidate($0) }
    }

    private static func addCoTagSuggestions(
        for targetBook: TagSuggestionBookSnapshot,
        in index: TagsDomainIndex,
        selectedTagKeys: Set<String>,
        existingTagAggregates: [String: ExistingTagAggregate],
        aggregates: inout [String: SuggestionAggregate]
    ) {
        guard !selectedTagKeys.isEmpty else { return }

        for book in index.suggestionSnapshots where book.id != targetBook.id {
            let bookTags = index.normalizedTags(for: book.id)
            let bookTagKeys = Set(bookTags.map { suggestionKey($0) })
            let overlapCount = selectedTagKeys.intersection(bookTagKeys).count
            guard overlapCount > 0 else { continue }

            for tag in bookTags {
                addCandidate(
                    tag,
                    reason: .coTag,
                    score: Score.coTag + (overlapCount * Score.coTagOverlapBonus),
                    relatedBookID: book.id,
                    selectedTagKeys: selectedTagKeys,
                    existingTagAggregates: existingTagAggregates,
                    aggregates: &aggregates
                )
            }
        }
    }

    private static func addSimilarBookSuggestions(
        for targetBook: TagSuggestionBookSnapshot,
        in index: TagsDomainIndex,
        selectedTagKeys: Set<String>,
        existingTagAggregates: [String: ExistingTagAggregate],
        aggregates: inout [String: SuggestionAggregate]
    ) {
        let targetCategoryKeys = Set(categoryCandidates(for: targetBook).map { suggestionKey($0) })
        let targetMainCategoryKey = comparableMainCategoryKey(targetBook.mainCategory)

        for book in index.suggestionSnapshots where book.id != targetBook.id {
            let similarityScore = similarity(
                between: targetBook,
                and: book,
                targetCategoryKeys: targetCategoryKeys,
                otherCategoryKeys: index.categoryCandidateKeys(for: book.id),
                targetMainCategoryKey: targetMainCategoryKey,
                otherMainCategoryKey: index.comparableMainCategoryKey(for: book.id)
            )
            guard similarityScore >= 2 else { continue }

            for tag in index.normalizedTags(for: book.id) {
                addCandidate(
                    tag,
                    reason: .similarBook,
                    score: similarityScore * Score.similarBookUnit,
                    relatedBookID: book.id,
                    selectedTagKeys: selectedTagKeys,
                    existingTagAggregates: existingTagAggregates,
                    aggregates: &aggregates
                )
            }
        }
    }

    private static func addCandidate(
        _ rawTag: String,
        reason: TagSuggestionReason,
        score: Int,
        relatedBookID: UUID?,
        selectedTagKeys: Set<String>,
        existingTagAggregates: [String: ExistingTagAggregate],
        existingTagCount: Int? = nil,
        aggregates: inout [String: SuggestionAggregate]
    ) {
        let normalizedTag = normalizeTagString(rawTag)
        guard !normalizedTag.isEmpty else { return }

        let key = suggestionKey(normalizedTag)
        guard !selectedTagKeys.contains(key) else { return }

        let existing = existingTagAggregates[key]
        let displayTag = existing?.tag ?? normalizedTag
        var aggregate = aggregates[key] ?? SuggestionAggregate(tag: displayTag)

        if let existing, existing.count > aggregate.existingTagCount {
            aggregate.existingTagCount = existing.count
            aggregate.tag = existing.tag
        }

        if let existingTagCount, existingTagCount > aggregate.existingTagCount {
            aggregate.existingTagCount = existingTagCount
        }

        aggregate.score += score
        aggregate.reasons.insert(reason)

        if let relatedBookID {
            aggregate.relatedBookIDs.insert(relatedBookID)
        }

        aggregates[key] = aggregate
    }

    private static func existingTagCounts(in index: TagsDomainIndex) -> [String: ExistingTagAggregate] {
        Dictionary(
            uniqueKeysWithValues: index.usageIndex.entries.map { entry in
                (
                    suggestionKey(entry.tag),
                    ExistingTagAggregate(tag: entry.tag, count: entry.count)
                )
            }
        )
    }

    private static func similarity(
        between targetBook: TagSuggestionBookSnapshot,
        and otherBook: TagSuggestionBookSnapshot,
        targetCategoryKeys: Set<String>,
        otherCategoryKeys: Set<String>,
        targetMainCategoryKey: String?,
        otherMainCategoryKey: String?
    ) -> Int {
        var score = 0

        if let targetAuthor = cleanComparableText(targetBook.author),
           let otherAuthor = cleanComparableText(otherBook.author),
           targetAuthor == otherAuthor {
            score += 3
        }

        if let targetMainCategoryKey,
           let otherMainCategoryKey,
           targetMainCategoryKey == otherMainCategoryKey {
            score += 3
        }

        let sharedCategoryCount = targetCategoryKeys.intersection(otherCategoryKeys).count
        score += min(3, sharedCategoryCount)

        return score
    }

    private static func comparableMainCategoryKey(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let candidates = categoryCandidates(categories: [], mainCategory: rawValue)
        guard let first = candidates.first else { return nil }
        return suggestionKey(first)
    }

    private static func cleanComparableText(_ rawValue: String) -> String? {
        let normalized = rawValue
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    private static func fallbackCategoryTokens(from rawValue: String) -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let separators = [
            " / ", "/",
            " > ", ">",
            " | ", "|",
            " ; ", ";",
            " , ", ",",
            " & ", "&",
            " und ",
            " and ",
            " + ", "+",
            " · ", "·",
            "•"
        ]

        var work = " " + trimmed + " "
        for separator in separators {
            work = work.replacingOccurrences(of: separator, with: " | ")
        }

        return work
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isUsefulCategoryCandidate($0) }
    }

    private static func isUsefulCategoryCandidate(_ rawValue: String) -> Bool {
        let normalized = normalizeTagString(rawValue)
        guard !normalized.isEmpty else { return false }

        let folded = normalized
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if genericCategoryNoise.contains(folded) {
            return false
        }

        let alphaNumericCount = normalized.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        if alphaNumericCount >= 3 {
            return true
        }

        return normalized.contains("#") && alphaNumericCount >= 1
    }

    private static var genericCategoryNoise: Set<String> {
        [
            "general",
            "fiction",
            "nonfiction",
            "non fiction",
            "books",
            "subjects",
            "unclassified",
            "non classifiable"
        ]
    }

    private static func uniqueNormalizedTags(_ tags: [String]) -> [String] {
        TagsIndexBuilder.uniqueNormalizedTags(tags)
    }

    private static func suggestionKey(_ tag: String) -> String {
        normalizeTagString(tag)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func orderedReasons(from reasons: Set<TagSuggestionReason>) -> [TagSuggestionReason] {
        TagSuggestionReason.allCases.filter { reasons.contains($0) }
    }
}
