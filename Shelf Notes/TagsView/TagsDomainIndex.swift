import Foundation

struct TagsSourceSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let categories: [String]
    let mainCategory: String?
    let tags: [String]
    let statusRawValue: String

    init(
        id: UUID,
        title: String,
        author: String,
        categories: [String] = [],
        mainCategory: String? = nil,
        tags: [String],
        statusRawValue: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.categories = categories
        self.mainCategory = mainCategory
        self.tags = tags
        self.statusRawValue = statusRawValue
    }

    @MainActor
    init(book: Book) {
        self.init(
            id: book.id,
            title: book.title,
            author: book.author,
            categories: book.categories,
            mainCategory: book.mainCategory,
            tags: book.tags,
            statusRawValue: book.statusRawValue
        )
    }

    init(dashboardSnapshot: TagsDashboardBookSnapshot) {
        self.init(
            id: dashboardSnapshot.id,
            title: dashboardSnapshot.title,
            author: dashboardSnapshot.author,
            categories: [],
            mainCategory: nil,
            tags: dashboardSnapshot.tags,
            statusRawValue: dashboardSnapshot.statusRawValue
        )
    }

    init(suggestionSnapshot: TagSuggestionBookSnapshot) {
        self.init(
            id: suggestionSnapshot.id,
            title: suggestionSnapshot.title,
            author: suggestionSnapshot.author,
            categories: suggestionSnapshot.categories,
            mainCategory: suggestionSnapshot.mainCategory,
            tags: suggestionSnapshot.tags,
            statusRawValue: suggestionSnapshot.statusRawValue
        )
    }

    var dashboardSnapshot: TagsDashboardBookSnapshot {
        TagsDashboardBookSnapshot(
            id: id,
            title: title,
            author: author,
            statusRawValue: statusRawValue,
            tags: tags
        )
    }

    var suggestionSnapshot: TagSuggestionBookSnapshot {
        TagSuggestionBookSnapshot(
            id: id,
            title: title,
            author: author,
            tags: tags,
            categories: categories,
            mainCategory: mainCategory,
            statusRawValue: statusRawValue
        )
    }

    var mutationSnapshot: TagLibraryMutationBookSnapshot {
        TagLibraryMutationBookSnapshot(id: id, tags: tags)
    }
}

struct TagsSourceSignature: Hashable {
    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    init(sourceSnapshots: [TagsSourceSnapshot]) {
        var aggregate: UInt64 = 0xA24B_AED4_963E_E407
        aggregate &+= UInt64(sourceSnapshots.count) &* 0x9FB2_1C65_1E98_DF25

        for snapshot in sourceSnapshots.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            var hasher = Hasher()
            hasher.combine(snapshot.id)
            hasher.combine(snapshot.title)
            hasher.combine(snapshot.author)
            hasher.combine(snapshot.statusRawValue)
            hasher.combine(snapshot.mainCategory)
            hasher.combine(snapshot.tags.count)
            for rawTag in snapshot.tags {
                hasher.combine(rawTag)
                hasher.combine(normalizeTagString(rawTag))
            }
            hasher.combine(snapshot.categories.count)
            for category in snapshot.categories {
                hasher.combine(category)
                hasher.combine(normalizeTagString(category))
            }

            let value = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= value &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }

        self.rawValue = aggregate
    }

    static let empty = TagsSourceSignature(rawValue: 0xA24B_AED4_963E_E407)
}

struct TagsDomainIndex {
    struct TagOccurrence: Hashable {
        let rawTag: String
        let trimmedRawTag: String
        let normalizedTag: String
        let bookID: UUID

        var normalizedKey: String {
            TagsDomainIndex.hygieneKey(normalizedTag)
        }

        var hasStorageFormattingIssue: Bool {
            rawTag != normalizedTag
        }
    }

    static let empty = TagsDomainIndex(sourceSnapshots: [])

    let totalBooks: Int
    let sourceSnapshots: [TagsSourceSnapshot]
    let dashboardSnapshots: [TagsDashboardBookSnapshot]
    let mutationSnapshots: [TagLibraryMutationBookSnapshot]
    let usageIndex: TagUsageIndex
    let occurrences: [TagOccurrence]
    let normalizedTagsByBookID: [UUID: [String]]
    let suggestionSnapshots: [TagSuggestionBookSnapshot]
    let categoryCandidatesByBookID: [UUID: [String]]
    let comparableMainCategoryKeyByBookID: [UUID: String]
    let sourceSignature: TagsSourceSignature
    let inputSignature: UInt64

    var tagCounts: [TagsIndexBuilder.TagCount] {
        usageIndex.tagCounts
    }

    init(snapshots: [TagsDashboardBookSnapshot]) {
        self.init(sourceSnapshots: snapshots.map(TagsSourceSnapshot.init(dashboardSnapshot:)))
    }

    init(suggestionSnapshots: [TagSuggestionBookSnapshot]) {
        self.init(sourceSnapshots: suggestionSnapshots.map(TagsSourceSnapshot.init(suggestionSnapshot:)))
    }

    init(sourceSnapshots: [TagsSourceSnapshot]) {
        self.init(
            sourceSnapshots: sourceSnapshots,
            sourceSignature: TagsSourceSignature(sourceSnapshots: sourceSnapshots)
        )
    }

    func normalizedTags(for bookID: UUID) -> [String] {
        normalizedTagsByBookID[bookID] ?? []
    }

    func categoryCandidates(for bookID: UUID) -> [String] {
        categoryCandidatesByBookID[bookID] ?? []
    }

    func categoryCandidateKeys(for bookID: UUID) -> Set<String> {
        Set(categoryCandidates(for: bookID).map { Self.suggestionKey($0) })
    }

    func comparableMainCategoryKey(for bookID: UUID) -> String? {
        comparableMainCategoryKeyByBookID[bookID]
    }

    func autocompleteSuggestions(
        query: String,
        selectedTags: [String],
        limit: Int = 8
    ) -> [String] {
        TagsIndexBuilder.autocompleteSuggestions(
            query: query,
            selectedTags: selectedTags,
            tagCounts: tagCounts,
            limit: limit
        )
    }

    init(
        sourceSnapshots: [TagsSourceSnapshot],
        sourceSignature: TagsSourceSignature
    ) {
        totalBooks = sourceSnapshots.count

        var occurrences: [TagOccurrence] = []
        var normalizedTagsByBookID: [UUID: [String]] = [:]
        var aggregates: [String: TagAggregate] = [:]
        var originalSpellingsByKey: [String: [String]] = [:]
        var taggedBookIDs: Set<UUID> = []
        var untaggedBookIDs: [UUID] = []
        var totalTagUsages = 0
        var suggestionSnapshots: [TagSuggestionBookSnapshot] = []
        var dashboardSnapshots: [TagsDashboardBookSnapshot] = []
        var mutationSnapshots: [TagLibraryMutationBookSnapshot] = []
        var categoryCandidatesByBookID: [UUID: [String]] = [:]
        var comparableMainCategoryKeyByBookID: [UUID: String] = [:]

        suggestionSnapshots.reserveCapacity(sourceSnapshots.count)
        dashboardSnapshots.reserveCapacity(sourceSnapshots.count)
        mutationSnapshots.reserveCapacity(sourceSnapshots.count)

        for snapshot in sourceSnapshots {
            dashboardSnapshots.append(snapshot.dashboardSnapshot)
            suggestionSnapshots.append(snapshot.suggestionSnapshot)
            mutationSnapshots.append(snapshot.mutationSnapshot)

            var uniqueTags: [String] = []
            uniqueTags.reserveCapacity(snapshot.tags.count)

            for rawTag in snapshot.tags {
                let normalizedTag = normalizeTagString(rawTag)
                guard !normalizedTag.isEmpty else { continue }

                let trimmedRawTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                let usageKey = normalizedTag.lowercased()
                var originalSpellings = originalSpellingsByKey[usageKey] ?? []

                if !originalSpellings.contains(where: { $0 == trimmedRawTag }) {
                    originalSpellings.append(trimmedRawTag)
                    originalSpellingsByKey[usageKey] = originalSpellings
                }

                occurrences.append(
                    TagOccurrence(
                        rawTag: rawTag,
                        trimmedRawTag: trimmedRawTag,
                        normalizedTag: normalizedTag,
                        bookID: snapshot.id
                    )
                )

                if !uniqueTags.contains(where: { $0.caseInsensitiveCompare(normalizedTag) == .orderedSame }) {
                    uniqueTags.append(normalizedTag)
                }
            }

            normalizedTagsByBookID[snapshot.id] = uniqueTags

            if uniqueTags.isEmpty {
                untaggedBookIDs.append(snapshot.id)
            } else {
                taggedBookIDs.insert(snapshot.id)
            }

            for tag in uniqueTags {
                let key = tag.lowercased()
                var aggregate = aggregates[key] ?? TagAggregate(
                    key: key,
                    tag: tag,
                    bookIDs: [],
                    statusCounts: TagsDashboardStatusCounts()
                )

                aggregate.bookIDs.append(snapshot.id)
                aggregate.statusCounts.increment(statusRawValue: snapshot.statusRawValue)

                aggregates[key] = aggregate
                totalTagUsages += 1
            }

            let categoryCandidates = TagSuggestionEngine.categoryCandidates(
                categories: snapshot.categories,
                mainCategory: snapshot.mainCategory
            )
            categoryCandidatesByBookID[snapshot.id] = categoryCandidates

            if let comparableMainCategoryKey = Self.comparableMainCategoryKey(snapshot.mainCategory) {
                comparableMainCategoryKeyByBookID[snapshot.id] = comparableMainCategoryKey
            }
        }

        let entries = aggregates.values
            .map { aggregate in
                TagUsageIndex.Entry(
                    key: aggregate.key,
                    tag: aggregate.tag,
                    bookIDs: aggregate.bookIDs,
                    statusCounts: aggregate.statusCounts,
                    originalSpellings: originalSpellingsByKey[aggregate.key] ?? [aggregate.tag]
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }

                return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
            }

        self.sourceSnapshots = sourceSnapshots
        self.dashboardSnapshots = dashboardSnapshots
        self.mutationSnapshots = mutationSnapshots
        self.occurrences = occurrences
        self.normalizedTagsByBookID = normalizedTagsByBookID
        self.suggestionSnapshots = suggestionSnapshots
        self.categoryCandidatesByBookID = categoryCandidatesByBookID
        self.comparableMainCategoryKeyByBookID = comparableMainCategoryKeyByBookID
        self.sourceSignature = sourceSignature
        self.inputSignature = sourceSignature.rawValue
        self.usageIndex = TagUsageIndex(
            entries: entries,
            entriesByKey: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0) }),
            untaggedBookIDs: untaggedBookIDs,
            taggedBookIDsCount: taggedBookIDs.count,
            totalTagUsages: totalTagUsages
        )
    }

    private struct TagAggregate {
        let key: String
        let tag: String
        var bookIDs: [UUID]
        var statusCounts: TagsDashboardStatusCounts
    }

    private static func hygieneKey(_ tag: String) -> String {
        normalizeTagString(tag)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func suggestionKey(_ tag: String) -> String {
        normalizeTagString(tag)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func comparableMainCategoryKey(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let candidates = TagSuggestionEngine.categoryCandidates(categories: [], mainCategory: rawValue)
        guard let first = candidates.first else { return nil }
        return suggestionKey(first)
    }
}
