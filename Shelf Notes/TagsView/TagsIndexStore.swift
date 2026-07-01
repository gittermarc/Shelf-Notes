//
//  TagsIndexStore.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.04.26.
//  TAGS-INDEX-STORE-1: Central app-wide tag index cache.
//

import Foundation
import Combine
import Observation

@MainActor
final class TagsIndexStore: ObservableObject {
    typealias TagCount = TagsIndexBuilder.TagCount
    typealias BookTagsSnapshot = TagsIndexBuilder.BookTagsSnapshot

    @Published private(set) var tagCounts: [TagCount] = []
    @Published private(set) var domainIndex = TagsDomainIndex.empty
    @Published private(set) var dashboard = TagsDashboardBuilder.build(index: .empty)
    @Published private(set) var hygieneReport = TagHygieneBuilder.build(index: .empty)

    private var lastTagCountsSignature: UInt64 = 0
    private var didComputeTagCountsOnce: Bool = false
    private var lastDomainSourceSignature = TagsSourceSignature.empty
    private var didComputeDomainIndexOnce: Bool = false
    private var observedBooks: [Book] = []
    private var trackingGeneration = 0
    private(set) var completedDomainIndexBuildCount = 0

    var sourceSignature: TagsSourceSignature {
        domainIndex.sourceSignature
    }

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
    func update(sourceSnapshots: [TagsSourceSnapshot]) -> Bool {
        let signature = TagsSourceSignature(sourceSnapshots: sourceSnapshots)
        return update(sourceSnapshots: sourceSnapshots, signature: signature)
    }

    @discardableResult
    func update(sourceSnapshots: [TagsSourceSnapshot], signature: TagsSourceSignature) -> Bool {
        guard didComputeDomainIndexOnce == false || signature != lastDomainSourceSignature else {
            return false
        }

        let newDomainIndex = TagsDomainIndex(sourceSnapshots: sourceSnapshots, sourceSignature: signature)
        updatePublishedState(domainIndex: newDomainIndex)
        lastDomainSourceSignature = signature
        didComputeDomainIndexOnce = true
        didComputeTagCountsOnce = true
        lastTagCountsSignature = signature.rawValue
        completedDomainIndexBuildCount += 1
        return true
    }

    @discardableResult
    func update(suggestionSnapshots: [TagSuggestionBookSnapshot]) -> Bool {
        update(sourceSnapshots: suggestionSnapshots.map(TagsSourceSnapshot.init(suggestionSnapshot:)))
    }

    @discardableResult
    func update(domainIndex newDomainIndex: TagsDomainIndex) -> Bool {
        let signature = newDomainIndex.sourceSignature
        guard didComputeDomainIndexOnce == false || signature != lastDomainSourceSignature else {
            return false
        }

        updatePublishedState(domainIndex: newDomainIndex)
        lastDomainSourceSignature = signature
        didComputeDomainIndexOnce = true
        didComputeTagCountsOnce = true
        lastTagCountsSignature = signature.rawValue
        completedDomainIndexBuildCount += 1
        return true
    }

    @discardableResult
    func update(books: [Book]) -> Bool {
        update(sourceSnapshots: TagsIndexBuilder.makeSourceSnapshots(books: books))
    }

    @discardableResult
    func update(books: [Book], signature: UInt64) -> Bool {
        update(
            sourceSnapshots: TagsIndexBuilder.makeSourceSnapshots(books: books),
            signature: TagsSourceSignature(rawValue: signature)
        )
    }

    func refreshSourceAndTrack(books: [Book]) {
        observedBooks = books
        refreshObservedBooksAndTrack()
    }

    func refreshSource(books: [Book]) {
        update(books: books)
    }

    static func taskSignature(books: [Book]) -> UInt64 {
        TagsIndexBuilder.sourceTaskSignature(books: books)
    }

    private func refreshObservedBooksAndTrack() {
        trackingGeneration += 1
        let generation = trackingGeneration

        let snapshots = withObservationTracking {
            TagsIndexBuilder.makeSourceSnapshots(books: observedBooks)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.trackingGeneration == generation else { return }
                self.refreshObservedBooksAndTrack()
            }
        }

        update(sourceSnapshots: snapshots)
    }

    private func updatePublishedState(domainIndex newDomainIndex: TagsDomainIndex) {
        domainIndex = newDomainIndex
        tagCounts = newDomainIndex.tagCounts
        dashboard = TagsDashboardBuilder.build(index: newDomainIndex)
        hygieneReport = TagHygieneBuilder.build(index: newDomainIndex)
    }
}
