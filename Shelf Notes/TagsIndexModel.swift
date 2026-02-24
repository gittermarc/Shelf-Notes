//
//  TagsIndexModel.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 24.02.26.
//  P0.1: Cache tag counts for TagsView (keeps O(n) aggregation out of the render path).
//

import Foundation
import Combine

@MainActor
final class TagsIndexModel: ObservableObject {

    // MARK: - Types

    struct TagCount: Identifiable, Hashable {
        let tag: String
        let count: Int

        var id: String { tag }
    }

    /// Lightweight value snapshot so the model doesn't need to keep SwiftData `Book` references.
    struct BookTagsSnapshot: Hashable {
        let id: UUID
        let tags: [String]
    }

    // MARK: - State

    @Published private(set) var tagCounts: [TagCount] = []

    private var lastSignature: UInt64 = 0
    private var didComputeOnce: Bool = false

    // MARK: - API

    func update(snapshot: [BookTagsSnapshot]) {
        let signature = Self.computeSignature(snapshot: snapshot)
        guard didComputeOnce == false || signature != lastSignature else { return }

        didComputeOnce = true
        lastSignature = signature
        tagCounts = Self.computeTagCounts(snapshot: snapshot)
    }

    // MARK: - Implementation

    private static func computeTagCounts(snapshot: [BookTagsSnapshot]) -> [TagCount] {
        var counts: [String: Int] = [:]
        counts.reserveCapacity(64)

        for book in snapshot {
            for rawTag in book.tags {
                let normalized = normalizeTagString(rawTag)
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }

        return counts
            .map { TagCount(tag: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
            }
    }

    /// Order-independent signature (so reordering query results doesn't force a recompute).
    ///
    /// Note: `Hasher` isn't stable across launches — that's totally fine here because we only
    /// use this for in-memory caching within one app run.
    private static func computeSignature(snapshot: [BookTagsSnapshot]) -> UInt64 {
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
            // Commutative-ish mixing into the aggregate.
            aggregate ^= h &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }

        return aggregate
    }
}
