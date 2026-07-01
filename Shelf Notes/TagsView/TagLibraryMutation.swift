import Foundation

enum TagLibraryMutationKind: String, Hashable {
    case rename
    case delete
    case merge
}

struct TagLibraryMutationBookSnapshot: Identifiable, Hashable {
    let id: UUID
    let tags: [String]
}

struct TagLibraryMutationBookChange: Identifiable, Hashable {
    let id: UUID
    let oldTags: [String]
    let newTags: [String]
}

struct TagLibraryMutationResult: Hashable {
    let kind: TagLibraryMutationKind
    let sourceTags: [String]
    let targetTag: String?
    let changes: [TagLibraryMutationBookChange]

    var changedBookIDs: [UUID] {
        changes.map(\.id)
    }

    var changedBooksCount: Int {
        changes.count
    }

    var hasChanges: Bool {
        !changes.isEmpty
    }
}

enum TagLibraryMutation {

    static func makeSnapshots(books: [Book]) -> [TagLibraryMutationBookSnapshot] {
        books.map { book in
            TagLibraryMutationBookSnapshot(id: book.id, tags: book.tags)
        }
    }

    static func makeSnapshots(sourceSnapshots: [TagsSourceSnapshot]) -> [TagLibraryMutationBookSnapshot] {
        sourceSnapshots.map(\.mutationSnapshot)
    }

    static func makeSnapshots(index: TagsDomainIndex) -> [TagLibraryMutationBookSnapshot] {
        index.mutationSnapshots
    }

    static func rename(
        tag sourceTag: String,
        to targetTag: String,
        in snapshots: [TagLibraryMutationBookSnapshot]
    ) -> TagLibraryMutationResult {
        let source = normalizeTagString(sourceTag)
        let target = normalizeTagString(targetTag)

        guard !source.isEmpty, !target.isEmpty else {
            return emptyResult(kind: .rename, sourceTags: [source], targetTag: target)
        }

        return rewrite(
            kind: .rename,
            sourceTags: [source],
            replacementKeys: [source.lowercased()],
            targetTag: target,
            snapshots: snapshots
        )
    }

    static func delete(
        tag sourceTag: String,
        in snapshots: [TagLibraryMutationBookSnapshot]
    ) -> TagLibraryMutationResult {
        let source = normalizeTagString(sourceTag)

        guard !source.isEmpty else {
            return emptyResult(kind: .delete, sourceTags: [], targetTag: nil)
        }

        return rewrite(
            kind: .delete,
            sourceTags: [source],
            replacementKeys: [source.lowercased()],
            targetTag: nil,
            snapshots: snapshots
        )
    }

    static func merge(
        sourceTags rawSourceTags: [String],
        into rawTargetTag: String,
        in snapshots: [TagLibraryMutationBookSnapshot]
    ) -> TagLibraryMutationResult {
        let target = normalizeTagString(rawTargetTag)
        let sources = uniqueNormalizedTags(rawSourceTags)

        guard !target.isEmpty, !sources.isEmpty else {
            return emptyResult(kind: .merge, sourceTags: sources, targetTag: target)
        }

        var replacementKeys = Set(sources.map { $0.lowercased() })
        replacementKeys.insert(target.lowercased())

        return rewrite(
            kind: .merge,
            sourceTags: sources,
            replacementKeys: replacementKeys,
            targetTag: target,
            snapshots: snapshots
        )
    }

    @discardableResult
    static func apply(_ result: TagLibraryMutationResult, to books: [Book]) -> Int {
        guard result.hasChanges else { return 0 }

        let changesByID = Dictionary(uniqueKeysWithValues: result.changes.map { ($0.id, $0.newTags) })
        var appliedCount = 0

        for book in books {
            guard let updatedTags = changesByID[book.id] else { continue }
            book.tags = updatedTags
            appliedCount += 1
        }

        return appliedCount
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

    private static func rewrite(
        kind: TagLibraryMutationKind,
        sourceTags: [String],
        replacementKeys: Set<String>,
        targetTag: String?,
        snapshots: [TagLibraryMutationBookSnapshot]
    ) -> TagLibraryMutationResult {
        let changes = snapshots.compactMap { snapshot -> TagLibraryMutationBookChange? in
            let affectsBook = snapshot.tags.contains { rawTag in
                let normalized = normalizeTagString(rawTag)
                return replacementKeys.contains(normalized.lowercased())
            }

            guard affectsBook else { return nil }

            let rewrittenTags = rewriteTags(
                snapshot.tags,
                replacementKeys: replacementKeys,
                targetTag: targetTag
            )

            guard rewrittenTags != snapshot.tags else { return nil }

            return TagLibraryMutationBookChange(
                id: snapshot.id,
                oldTags: snapshot.tags,
                newTags: rewrittenTags
            )
        }

        return TagLibraryMutationResult(
            kind: kind,
            sourceTags: sourceTags,
            targetTag: targetTag,
            changes: changes
        )
    }

    private static func rewriteTags(
        _ tags: [String],
        replacementKeys: Set<String>,
        targetTag: String?
    ) -> [String] {
        var out: [String] = []
        out.reserveCapacity(tags.count)

        for rawTag in tags {
            let normalized = normalizeTagString(rawTag)
            guard !normalized.isEmpty else { continue }

            let candidate: String?
            if replacementKeys.contains(normalized.lowercased()) {
                candidate = targetTag
            } else {
                candidate = normalized
            }

            guard let candidate, !candidate.isEmpty else { continue }

            if !out.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) {
                out.append(candidate)
            }
        }

        return out
    }

    private static func emptyResult(
        kind: TagLibraryMutationKind,
        sourceTags: [String],
        targetTag: String?
    ) -> TagLibraryMutationResult {
        TagLibraryMutationResult(
            kind: kind,
            sourceTags: sourceTags.filter { !$0.isEmpty },
            targetTag: targetTag?.isEmpty == true ? nil : targetTag,
            changes: []
        )
    }
}
