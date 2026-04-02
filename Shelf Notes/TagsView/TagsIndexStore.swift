//
//  TagsIndexStore.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.04.26.
//  TAGS-INDEX-STORE-1: Central app-wide tag index cache.
//

import Foundation
import Combine

@MainActor
final class TagsIndexStore: ObservableObject {
    typealias TagCount = TagsIndexBuilder.TagCount
    typealias BookTagsSnapshot = TagsIndexBuilder.BookTagsSnapshot

    @Published private(set) var tagCounts: [TagCount] = []

    private var lastSignature: UInt64 = 0
    private var didComputeOnce: Bool = false

    @discardableResult
    func update(snapshot: [BookTagsSnapshot], signature: UInt64) -> Bool {
        guard didComputeOnce == false || signature != lastSignature else {
            return false
        }

        didComputeOnce = true
        lastSignature = signature
        tagCounts = TagsIndexBuilder.computeTagCounts(snapshot: snapshot)
        return true
    }

    @discardableResult
    func update(snapshot: [BookTagsSnapshot]) -> Bool {
        update(
            snapshot: snapshot,
            signature: TagsIndexBuilder.computeSignature(snapshot: snapshot)
        )
    }

    func update(books: [Book], signature: UInt64) {
        let snapshot = TagsIndexBuilder.makeSnapshot(books: books)
        update(snapshot: snapshot, signature: signature)
    }

    static func taskSignature(books: [Book]) -> UInt64 {
        TagsIndexBuilder.taskSignature(books: books)
    }
}
