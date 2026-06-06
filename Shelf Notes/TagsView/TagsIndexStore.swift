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
    @Published private(set) var domainIndex = TagsDomainIndex(suggestionSnapshots: [])

    private var lastTagCountsSignature: UInt64 = 0
    private var didComputeTagCountsOnce: Bool = false
    private var lastDomainIndexSignature: UInt64 = 0
    private var didComputeDomainIndexOnce: Bool = false

    @discardableResult
    func update(snapshot: [BookTagsSnapshot], signature: UInt64) -> Bool {
        guard didComputeTagCountsOnce == false || signature != lastTagCountsSignature else {
            return false
        }

        didComputeTagCountsOnce = true
        lastTagCountsSignature = signature
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

    @discardableResult
    func update(suggestionSnapshots: [TagSuggestionBookSnapshot]) -> Bool {
        update(domainIndex: TagsDomainIndex(suggestionSnapshots: suggestionSnapshots))
    }

    @discardableResult
    func update(domainIndex newDomainIndex: TagsDomainIndex) -> Bool {
        let signature = newDomainIndex.inputSignature
        guard didComputeDomainIndexOnce == false || signature != lastDomainIndexSignature else {
            return false
        }

        didComputeDomainIndexOnce = true
        didComputeTagCountsOnce = true
        lastDomainIndexSignature = signature
        lastTagCountsSignature = signature
        domainIndex = newDomainIndex
        tagCounts = newDomainIndex.tagCounts
        return true
    }

    @discardableResult
    func update(books: [Book]) -> Bool {
        update(suggestionSnapshots: TagsIndexBuilder.makeSuggestionSnapshot(books: books))
    }

    @discardableResult
    func update(books: [Book], signature: UInt64) -> Bool {
        _ = signature
        return update(books: books)
    }

    static func taskSignature(books: [Book]) -> UInt64 {
        TagsIndexBuilder.suggestionTaskSignature(books: books)
    }
}
