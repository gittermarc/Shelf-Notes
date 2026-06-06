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

    @Test func storeCachesSuggestionDomainIndexAndSkipsIdenticalSignature() {
        let store = TagsIndexStore()
        let snapshots = [
            makeSuggestionSnapshot(1, title: "Noir One", author: "A. Author", tags: ["Crime"], categories: ["Fiction / Mystery & Detective"]),
            makeSuggestionSnapshot(2, title: "Noir Two", author: "A. Author", tags: ["Noir", "Crime"], categories: ["Fiction / Mystery & Detective"]),
            makeSuggestionSnapshot(3, title: "Space", author: "B. Author", tags: ["Sci-Fi"], categories: ["Science Fiction"])
        ]

        let didUpdate = store.update(suggestionSnapshots: snapshots)
        let didUpdateAgain = store.update(suggestionSnapshots: snapshots)

        #expect(didUpdate)
        #expect(!didUpdateAgain)
        #expect(store.domainIndex.suggestionSnapshots.map(\.id) == snapshots.map(\.id))
        #expect(store.tagCounts.map(\.tag) == ["Crime", "Noir", "Sci-Fi"])
        #expect(store.tagCounts.map(\.count) == [2, 1, 1])
    }

    @Test func cachedDomainIndexProducesSameSuggestionsAsDirectIndex() {
        let store = TagsIndexStore()
        let target = makeSuggestionSnapshot(
            1,
            title: "Noir One",
            author: "A. Author",
            tags: ["Crime"],
            categories: ["Fiction / Mystery & Detective"]
        )
        let snapshots = [
            target,
            makeSuggestionSnapshot(2, title: "Noir Two", author: "A. Author", tags: ["Noir", "Crime"], categories: ["Fiction / Mystery & Detective"]),
            makeSuggestionSnapshot(3, title: "Space", author: "B. Author", tags: ["Sci-Fi"], categories: ["Science Fiction"])
        ]
        let directIndex = TagsDomainIndex(suggestionSnapshots: snapshots)

        store.update(suggestionSnapshots: snapshots)

        let directState = TagSuggestionViewStateBuilder.make(
            target: target,
            domainIndex: directIndex,
            selectedTags: target.tags
        )
        let cachedState = TagSuggestionViewStateBuilder.make(
            target: target,
            domainIndex: store.domainIndex,
            selectedTags: target.tags
        )

        #expect(cachedState.smartItems.map(\.id) == directState.smartItems.map(\.id))
        #expect(cachedState.smartItems.map(\.reasonLabel) == directState.smartItems.map(\.reasonLabel))
        #expect(cachedState.frequentItems.map(\.id) == directState.frequentItems.map(\.id))
        #expect(cachedState.frequentItems.map(\.count) == directState.frequentItems.map(\.count))
    }

    private func makeSuggestionSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "Test Author",
        tags: [String],
        categories: [String] = [],
        mainCategory: String? = nil,
        status: ReadingStatus = .toRead
    ) -> TagSuggestionBookSnapshot {
        TagSuggestionBookSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            tags: tags,
            categories: categories,
            mainCategory: mainCategory,
            statusRawValue: status.rawValue
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
