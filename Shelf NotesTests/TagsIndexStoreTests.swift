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

    @Test func sourceStoreSkipsIdenticalTagRelevantInput() {
        let store = TagsIndexStore()
        let snapshots = [
            makeSourceSnapshot(1, title: "Noir One", tags: ["Crime"]),
            makeSourceSnapshot(2, title: "Noir Two", tags: ["Crime", "Noir"])
        ]

        let didUpdate = store.update(sourceSnapshots: snapshots)
        let didUpdateAgain = store.update(sourceSnapshots: snapshots)

        #expect(didUpdate)
        #expect(!didUpdateAgain)
        #expect(store.completedDomainIndexBuildCount == 1)
        #expect(store.dashboard.summary.totalBooks == 2)
        #expect(store.tagCounts.map(\.tag) == ["Crime", "Noir"])
    }

    @Test func sourceStoreRebuildsWhenTagsChange() {
        let store = TagsIndexStore()
        let first = [
            makeSourceSnapshot(1, title: "Noir One", tags: ["Crime"])
        ]
        let changedTags = [
            makeSourceSnapshot(1, title: "Noir One", tags: ["Crime", "Noir"])
        ]

        let firstUpdate = store.update(sourceSnapshots: first)
        let secondUpdate = store.update(sourceSnapshots: changedTags)

        #expect(firstUpdate)
        #expect(secondUpdate)
        #expect(store.completedDomainIndexBuildCount == 2)
        #expect(store.tagCounts.map(\.tag) == ["Crime", "Noir"])
    }

    @Test func sourceStoreIgnoresNonTagRelevantBookEdits() {
        let store = TagsIndexStore()
        let book = Book(title: "Noir One", author: "A. Author", status: .toRead, tags: ["Crime"])
        book.id = fixedID(90)

        store.refreshSource(books: [book])
        book.subtitle = "Nur Darstellung"
        book.notes = "Eine Notiz, die Tags nicht betrifft"
        store.refreshSource(books: [book])

        #expect(store.completedDomainIndexBuildCount == 1)
        #expect(store.tagCounts.map(\.tag) == ["Crime"])
    }

    @Test func cleanupMutationRefreshesSourceIndexAfterApply() {
        let store = TagsIndexStore()
        let first = Book(title: "One", author: "A", status: .finished, tags: ["Crime"])
        let second = Book(title: "Two", author: "B", status: .reading, tags: ["Noir"])
        first.id = fixedID(91)
        second.id = fixedID(92)

        store.refreshSource(books: [first, second])

        let result = TagLibraryMutation.rename(
            tag: "Crime",
            to: "Krimi",
            in: TagLibraryMutation.makeSnapshots(index: store.domainIndex)
        )
        _ = TagLibraryMutation.apply(result, to: [first, second])
        store.refreshSource(books: [first, second])

        #expect(result.hasChanges)
        #expect(store.completedDomainIndexBuildCount == 2)
        #expect(store.tagCounts.map(\.tag) == ["Krimi", "Noir"])
    }

    @Test func largeFixtureBuildsReusableDomainIndexOnce() {
        let store = TagsIndexStore()
        let fixture = LargeReadingDatasetBuilder.make1000BookMixedDataset()
        let books = fixture.books

        books[0].tags = [" #tag-0 ", "mood-0"]
        books[1].tags = ["tag-0", "mood-1"]
        books[2].tags = ["Sci-Fi", "mood-2"]
        books[3].tags = ["SciFi", "mood-3"]
        books[4].tags = []

        store.refreshSource(books: books)
        store.refreshSource(books: books)

        #expect(store.completedDomainIndexBuildCount == 1)
        #expect(store.domainIndex.totalBooks == 1000)
        #expect(store.dashboard.summary.totalBooks == 1000)
        #expect(store.tagCounts.count >= 10)
        #expect(store.hygieneReport.insights.contains { $0.kind == .formattingConflict })
        #expect(store.hygieneReport.insights.contains { $0.kind == .duplicateCandidate })
        #expect(store.hygieneReport.insights.contains { $0.kind == .untaggedBooks })
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

    private func makeSourceSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "Test Author",
        tags: [String],
        categories: [String] = [],
        mainCategory: String? = nil,
        status: ReadingStatus = .toRead
    ) -> TagsSourceSnapshot {
        TagsSourceSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            categories: categories,
            mainCategory: mainCategory,
            tags: tags,
            statusRawValue: status.rawValue
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
