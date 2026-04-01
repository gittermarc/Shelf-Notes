import Foundation
import Testing
@testable import Shelf_Notes

@MainActor
struct TagsIndexStoreTests {

    @Test func storeBuildsCountsFromSnapshotAndSkipsIdenticalSignature() {
        let store = TagsIndexStore()
        let snapshot = [
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["#Noir", "Crime"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["noir", "History"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["Crime"])
        ]
        let signature = TagsIndexBuilder.computeSignature(snapshot: snapshot)

        let didUpdate = store.update(snapshot: snapshot, signature: signature)
        let didUpdateAgain = store.update(snapshot: snapshot, signature: signature)

        #expect(didUpdate)
        #expect(!didUpdateAgain)
        #expect(store.tagCounts.map(\.tag) == ["Crime", "Noir", "History"])
        #expect(store.tagCounts.map(\.count) == [2, 2, 1])
    }

    @Test func storeRebuildsWhenSignatureChanges() {
        let store = TagsIndexStore()
        let firstSnapshot = [
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["History"])
        ]
        let secondSnapshot = [
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["History"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["#Noir", "history"])
        ]

        let firstSignature = TagsIndexBuilder.computeSignature(snapshot: firstSnapshot)
        let secondSignature = TagsIndexBuilder.computeSignature(snapshot: secondSnapshot)

        let firstUpdate = store.update(snapshot: firstSnapshot, signature: firstSignature)
        let secondUpdate = store.update(snapshot: secondSnapshot, signature: secondSignature)

        #expect(firstUpdate)
        #expect(secondUpdate)
        #expect(store.tagCounts.map(\.tag) == ["History", "Noir"])
        #expect(store.tagCounts.map(\.count) == [2, 1])
    }
}
