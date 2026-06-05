import Foundation

enum TagHygieneBuilder {

    private struct TagOccurrence: Hashable {
        let rawTag: String
        let trimmedRawTag: String
        let normalizedTag: String
        let bookID: UUID

        var normalizedKey: String {
            hygieneKey(normalizedTag)
        }

        var hasStorageFormattingIssue: Bool {
            rawTag != normalizedTag
        }
    }

    private struct TagGroup {
        let normalizedKey: String
        var displayTag: String
        var normalizedVariants: Set<String> = []
        var rawVariants: Set<String> = []
        var bookIDs: Set<UUID> = []
        var hasStorageFormattingIssue: Bool = false
    }

    private struct DuplicateGroup {
        let key: String
        var displayTagsByKey: [String: String] = [:]
        var bookIDsByKey: [String: Set<UUID>] = [:]

        var displayTags: [String] {
            displayTagsByKey.values.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }

        var bookIDs: Set<UUID> {
            bookIDsByKey.values.reduce(into: Set<UUID>()) { partialResult, ids in
                partialResult.formUnion(ids)
            }
        }
    }

    static func build(
        snapshots: [TagsDashboardBookSnapshot],
        maxInsights: Int = 6
    ) -> TagHygieneReport {
        let untaggedBookIDs = snapshots
            .filter { TagsDashboardBuilder.isUntagged($0) }
            .map(\.id)

        return build(
            snapshots: snapshots,
            untaggedBookIDs: untaggedBookIDs,
            maxInsights: maxInsights
        )
    }

    static func build(
        snapshots: [TagsDashboardBookSnapshot],
        untaggedBookIDs: [UUID],
        maxInsights: Int = 6
    ) -> TagHygieneReport {
        let occurrences = makeOccurrences(from: snapshots)

        var insights: [TagHygieneInsight] = []
        insights.append(contentsOf: formattingInsights(from: occurrences))
        insights.append(contentsOf: duplicateInsights(from: occurrences))

        if let singleUseInsight = singleUseInsight(from: occurrences) {
            insights.append(singleUseInsight)
        }

        if let untaggedInsight = untaggedInsight(bookIDs: untaggedBookIDs) {
            insights.append(untaggedInsight)
        }

        let sortedInsights = insights
            .sorted { insightSort($0, $1) }
            .prefix(max(0, maxInsights))
            .map { $0 }

        return TagHygieneReport(
            insights: sortedInsights,
            untaggedBookIDs: untaggedBookIDs
        )
    }

    private static func makeOccurrences(from snapshots: [TagsDashboardBookSnapshot]) -> [TagOccurrence] {
        var occurrences: [TagOccurrence] = []

        for snapshot in snapshots {
            for rawTag in snapshot.tags {
                let normalizedTag = normalizeTagString(rawTag)
                guard !normalizedTag.isEmpty else { continue }

                let trimmedRawTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                occurrences.append(
                    TagOccurrence(
                        rawTag: rawTag,
                        trimmedRawTag: trimmedRawTag,
                        normalizedTag: normalizedTag,
                        bookID: snapshot.id
                    )
                )
            }
        }

        return occurrences
    }

    private static func formattingInsights(from occurrences: [TagOccurrence]) -> [TagHygieneInsight] {
        var groups: [String: TagGroup] = [:]

        for occurrence in occurrences {
            var group = groups[occurrence.normalizedKey] ?? TagGroup(
                normalizedKey: occurrence.normalizedKey,
                displayTag: occurrence.normalizedTag
            )
            group.normalizedVariants.insert(occurrence.normalizedTag)
            group.rawVariants.insert(occurrence.trimmedRawTag)
            group.bookIDs.insert(occurrence.bookID)

            if occurrence.hasStorageFormattingIssue {
                group.hasStorageFormattingIssue = true
            }

            if preferredDisplayTag(occurrence.normalizedTag, over: group.displayTag) {
                group.displayTag = occurrence.normalizedTag
            }

            groups[occurrence.normalizedKey] = group
        }

        return groups.values.compactMap { group in
            let hasCaseConflict = Set(group.normalizedVariants.map { $0.lowercased() }).count == 1
                && group.normalizedVariants.count > 1
            let hasRawConflict = group.hasStorageFormattingIssue || group.rawVariants.count > group.normalizedVariants.count

            guard hasCaseConflict || hasRawConflict else { return nil }

            let variants = visibleFormattingVariants(group: group)
            let affectedBookIDs = group.bookIDs.sorted { uuidSort($0, $1) }
            let variantText = variants.prefix(4).joined(separator: " / ")
            let title: String

            if variantText.isEmpty {
                title = "Schreibweise prüfen: #\(group.displayTag)"
            } else {
                title = "Schreibweise prüfen: \(variantText)"
            }

            return TagHygieneInsight(
                kind: .formattingConflict,
                title: title,
                detail: "Groß-/Kleinschreibung, Leerzeichen oder führende # können diesen Tag uneinheitlich wirken lassen.",
                affectedTags: variants.isEmpty ? [group.displayTag] : variants,
                affectedBookIDs: affectedBookIDs,
                primaryTag: group.displayTag,
                actionTitle: "Tag ansehen"
            )
        }
    }

    private static func duplicateInsights(from occurrences: [TagOccurrence]) -> [TagHygieneInsight] {
        var normalizedTagBookIDs: [String: Set<UUID>] = [:]
        var displayTagByKey: [String: String] = [:]

        for occurrence in occurrences {
            normalizedTagBookIDs[occurrence.normalizedKey, default: []].insert(occurrence.bookID)

            if let currentDisplay = displayTagByKey[occurrence.normalizedKey] {
                if preferredDisplayTag(occurrence.normalizedTag, over: currentDisplay) {
                    displayTagByKey[occurrence.normalizedKey] = occurrence.normalizedTag
                }
            } else {
                displayTagByKey[occurrence.normalizedKey] = occurrence.normalizedTag
            }
        }

        var groups: [String: DuplicateGroup] = [:]

        for (normalizedKey, bookIDs) in normalizedTagBookIDs {
            guard let displayTag = displayTagByKey[normalizedKey] else { continue }

            for duplicateKey in duplicateKeys(for: displayTag) {
                var group = groups[duplicateKey] ?? DuplicateGroup(key: duplicateKey)
                group.displayTagsByKey[normalizedKey] = displayTag
                group.bookIDsByKey[normalizedKey] = bookIDs
                groups[duplicateKey] = group
            }
        }

        var seenTagSets: Set<String> = []

        return groups.values.compactMap { group in
            let tags = group.displayTags
            guard tags.count > 1 else { return nil }

            let signature = tags.map { $0.lowercased() }.joined(separator: "|")
            guard !seenTagSets.contains(signature) else { return nil }
            seenTagSets.insert(signature)

            let affectedBookIDs = group.bookIDs.sorted { uuidSort($0, $1) }
            let title = "Mögliche Duplikate: \(tags.prefix(4).joined(separator: " / "))"

            return TagHygieneInsight(
                kind: .duplicateCandidate,
                title: title,
                detail: "Diese Tags sehen nach Varianten derselben Idee aus. Bitte vor einem späteren Zusammenführen prüfen.",
                affectedTags: tags,
                affectedBookIDs: affectedBookIDs,
                primaryTag: tags.first,
                actionTitle: "Erstes Tag ansehen"
            )
        }
    }

    private static func singleUseInsight(from occurrences: [TagOccurrence]) -> TagHygieneInsight? {
        var bookIDsByTag: [String: Set<UUID>] = [:]
        var displayTagByKey: [String: String] = [:]

        for occurrence in occurrences {
            bookIDsByTag[occurrence.normalizedKey, default: []].insert(occurrence.bookID)

            if let currentDisplay = displayTagByKey[occurrence.normalizedKey] {
                if preferredDisplayTag(occurrence.normalizedTag, over: currentDisplay) {
                    displayTagByKey[occurrence.normalizedKey] = occurrence.normalizedTag
                }
            } else {
                displayTagByKey[occurrence.normalizedKey] = occurrence.normalizedTag
            }
        }

        let singleUsePairs = bookIDsByTag.compactMap { key, bookIDs -> (tag: String, bookID: UUID)? in
            guard bookIDs.count == 1, let tag = displayTagByKey[key], let bookID = bookIDs.first else {
                return nil
            }

            return (tag, bookID)
        }
        .sorted { lhs, rhs in
            localizedTagSort(lhs.tag, rhs.tag)
        }

        guard !singleUsePairs.isEmpty else { return nil }

        let tags = singleUsePairs.map(\.tag)
        let bookIDs = singleUsePairs.map(\.bookID).sorted { uuidSort($0, $1) }
        let count = tags.count
        let title = count == 1 ? "Einmal-Tag prüfen" : "\(count) Einmal-Tags prüfen"

        return TagHygieneInsight(
            kind: .singleUseTags,
            title: title,
            detail: "Diese Tags hängen jeweils nur an einem Buch. Das kann Absicht sein oder später schwer auffindbar werden.",
            affectedTags: tags,
            affectedBookIDs: bookIDs,
            primaryTag: tags.first,
            actionTitle: "Erstes Tag ansehen"
        )
    }

    private static func untaggedInsight(bookIDs: [UUID]) -> TagHygieneInsight? {
        guard !bookIDs.isEmpty else { return nil }

        let count = bookIDs.count
        let title = count == 1 ? "1 Buch ohne Tags" : "\(count) Bücher ohne Tags"

        return TagHygieneInsight(
            kind: .untaggedBooks,
            title: title,
            detail: "Diese Bücher sind noch keinem Thema, Genre oder Kontext zugeordnet.",
            affectedTags: [],
            affectedBookIDs: bookIDs.sorted { uuidSort($0, $1) },
            primaryTag: nil,
            actionTitle: "Bücher ansehen"
        )
    }

    private static func visibleFormattingVariants(group: TagGroup) -> [String] {
        var variants = group.rawVariants
            .filter { !$0.isEmpty }
            .map { rawVariant in
                if rawVariant == group.displayTag {
                    return rawVariant
                }

                return rawVariant
            }

        variants.append(contentsOf: group.normalizedVariants)
        return uniqueSortedTags(variants)
    }

    private static func duplicateKeys(for tag: String) -> [String] {
        guard !tag.contains("#") else { return [] }

        let folded = foldedAlphanumeric(tag)
        guard !folded.isEmpty else { return [] }

        if let aliasKey = aliasDuplicateKey(for: folded) {
            return ["alias:\(aliasKey)"]
        }

        if folded.count >= 4 {
            return ["shape:\(folded)"]
        }

        return []
    }

    private static func aliasDuplicateKey(for foldedTag: String) -> String? {
        switch foldedTag {
        case "nyc", "newyork", "newyorkcity":
            return "newyorkcity"
        case "scifi", "sciencefiction":
            return "sciencefiction"
        default:
            return nil
        }
    }

    private static func foldedAlphanumeric(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { character in
                character.isLetter || character.isNumber
            }
    }

    private static func hygieneKey(_ tag: String) -> String {
        normalizeTagString(tag)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func preferredDisplayTag(_ candidate: String, over current: String) -> Bool {
        let candidateStartsUppercase = candidate.first?.isUppercase == true
        let currentStartsUppercase = current.first?.isUppercase == true

        if candidateStartsUppercase != currentStartsUppercase {
            return candidateStartsUppercase
        }

        if candidate.count != current.count {
            return candidate.count < current.count
        }

        return candidate.localizedCaseInsensitiveCompare(current) == .orderedAscending
    }

    private static func uniqueSortedTags(_ tags: [String]) -> [String] {
        var output: [String] = []

        for tag in tags where !tag.isEmpty {
            if !output.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame && $0 == tag }) {
                output.append(tag)
            }
        }

        return output.sorted { localizedTagSort($0, $1) }
    }

    private static func insightSort(_ lhs: TagHygieneInsight, _ rhs: TagHygieneInsight) -> Bool {
        let lhsPriority = priority(for: lhs.kind)
        let rhsPriority = priority(for: rhs.kind)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        if lhs.affectedBooksCount != rhs.affectedBooksCount {
            return lhs.affectedBooksCount > rhs.affectedBooksCount
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func priority(for kind: TagHygieneInsightKind) -> Int {
        switch kind {
        case .formattingConflict:
            return 0
        case .duplicateCandidate:
            return 1
        case .singleUseTags:
            return 2
        case .untaggedBooks:
            return 3
        }
    }

    private static func localizedTagSort(_ lhs: String, _ rhs: String) -> Bool {
        let caseInsensitiveResult = lhs.localizedCaseInsensitiveCompare(rhs)

        if caseInsensitiveResult != .orderedSame {
            return caseInsensitiveResult == .orderedAscending
        }

        let localizedResult = lhs.localizedCompare(rhs)

        if localizedResult != .orderedSame {
            return localizedResult == .orderedAscending
        }

        return lhs < rhs
    }

    private static func uuidSort(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
