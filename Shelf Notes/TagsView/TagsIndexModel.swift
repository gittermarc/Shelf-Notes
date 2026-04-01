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
    typealias TagCount = TagsIndexBuilder.TagCount
    typealias BookTagsSnapshot = TagsIndexBuilder.BookTagsSnapshot

    // MARK: - State

    @Published private(set) var tagCounts: [TagCount] = []

    private var lastSignature: UInt64 = 0
    private var didComputeOnce: Bool = false

    // MARK: - API

    /// Updates cached counts from a lightweight snapshot.
    ///
    /// Pass a precomputed `signature` to avoid recomputing it inside the model.
    func update(snapshot: [BookTagsSnapshot], signature: UInt64) {
        guard didComputeOnce == false || signature != lastSignature else { return }

        didComputeOnce = true
        lastSignature = signature
        tagCounts = TagsIndexBuilder.computeTagCounts(snapshot: snapshot)
    }

    func update(snapshot: [BookTagsSnapshot]) {
        update(snapshot: snapshot, signature: TagsIndexBuilder.computeSignature(snapshot: snapshot))
    }

    /// Task-friendly, order-independent signature for a list of `Book` instances.
    ///
    /// This intentionally mirrors `computeSignature(snapshot:)` (same mixing),
    /// but avoids allocating arrays just to feed `.task(id:)`.
    static func taskSignature(books: [Book]) -> UInt64 {
        TagsIndexBuilder.taskSignature(books: books)
    }
}
