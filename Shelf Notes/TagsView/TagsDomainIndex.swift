import Foundation

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

    let totalBooks: Int
    let usageIndex: TagUsageIndex
    let occurrences: [TagOccurrence]
    let normalizedTagsByBookID: [UUID: [String]]
    let inputSignature: UInt64

    init(snapshots: [TagsDashboardBookSnapshot]) {
        totalBooks = snapshots.count

        var occurrences: [TagOccurrence] = []
        var normalizedTagsByBookID: [UUID: [String]] = [:]
        var aggregates: [String: TagAggregate] = [:]
        var originalSpellingsByKey: [String: [String]] = [:]
        var taggedBookIDs: Set<UUID> = []
        var untaggedBookIDs: [UUID] = []
        var totalTagUsages = 0
        var aggregateSignature: UInt64 = 0xC2B2_AE3D_27D4_EB4F
        aggregateSignature &+= UInt64(snapshots.count) &* 0x1656_67B1_9E37_79F9

        for snapshot in snapshots {
            var uniqueTags: [String] = []
            uniqueTags.reserveCapacity(snapshot.tags.count)

            var bookHasher = Hasher()
            bookHasher.combine(snapshot.id)
            bookHasher.combine(snapshot.statusRawValue)
            bookHasher.combine(snapshot.tags.count)

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
                bookHasher.combine(rawTag)
                bookHasher.combine(normalizedTag)

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

            let bookHash = UInt64(bitPattern: Int64(bookHasher.finalize()))
            aggregateSignature ^= bookHash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregateSignature << 6) &+ (aggregateSignature >> 2)
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

        self.occurrences = occurrences
        self.normalizedTagsByBookID = normalizedTagsByBookID
        self.inputSignature = aggregateSignature
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
}
