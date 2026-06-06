import Foundation
import Testing
@testable import Shelf_Notes

struct TagsIndexBuilderTests {

    @Test func normalizesAndDeduplicatesTagsCaseInsensitively() {
        let tags = TagsIndexBuilder.uniqueNormalizedTags([
            "  #Noir  ",
            "noir",
            " Crime ",
            "#crime",
            "",
            "   "
        ])

        #expect(tags == ["Noir", "Crime"])
    }

    @Test func parsesCommaSeparatedDraftsAndFallsBackToSingleTag() {
        let commaSeparated = TagsIndexBuilder.parsedTags(from: "  #Noir, Crime, noir,  ")
        let single = TagsIndexBuilder.parsedTags(from: "   #History  ")

        #expect(commaSeparated == ["Noir", "Crime"])
        #expect(single == ["History"])
    }

    @Test func computesStableCountsAcrossMultipleBooks() {
        let snapshot = [
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["#Noir", "Crime"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["noir", "History"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["Crime"])
        ]

        let counts = TagsIndexBuilder.computeTagCounts(snapshot: snapshot)

        #expect(counts.map(\.tag) == ["Crime", "Noir", "History"])
        #expect(counts.map(\.count) == [2, 2, 1])
    }

    @Test func tagIndexSignatureUsesOnlyBookIDsAndTags() {
        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let unchanged = [
            TagsIndexBuilder.BookTagsSnapshot(id: bookID, tags: ["#Noir", "Crime"])
        ]
        let sameTagSnapshotAfterIrrelevantBookEdits = [
            TagsIndexBuilder.BookTagsSnapshot(id: bookID, tags: ["#Noir", "Crime"])
        ]
        let changedTags = [
            TagsIndexBuilder.BookTagsSnapshot(id: bookID, tags: ["#Noir", "Crime", "History"])
        ]

        let unchangedSignature = TagsIndexBuilder.computeSignature(snapshot: unchanged)

        #expect(unchangedSignature == TagsIndexBuilder.computeSignature(snapshot: sameTagSnapshotAfterIrrelevantBookEdits))
        #expect(unchangedSignature != TagsIndexBuilder.computeSignature(snapshot: changedTags))
    }

    @MainActor
    @Test func suggestionSnapshotCapturesFieldsUsedByTagSuggestions() {
        let book = Book(title: "Project Hail Mary", author: "Andy Weir", status: .finished, tags: ["Sci-Fi"])
        book.id = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        book.categories = ["Science Fiction", "Space"]
        book.mainCategory = "Fiction"

        let snapshot = TagsIndexBuilder.makeSuggestionSnapshot(books: [book])

        #expect(snapshot.count == 1)
        #expect(snapshot.first?.id == book.id)
        #expect(snapshot.first?.title == "Project Hail Mary")
        #expect(snapshot.first?.author == "Andy Weir")
        #expect(snapshot.first?.tags == ["Sci-Fi"])
        #expect(snapshot.first?.categories == ["Science Fiction", "Space"])
        #expect(snapshot.first?.mainCategory == "Fiction")
        #expect(snapshot.first?.statusRawValue == ReadingStatus.finished.rawValue)
    }

    @MainActor
    @Test func suggestionSignatureIgnoresCollectionMembershipChanges() {
        let book = Book(title: "Noir Nights", author: "A. Author", status: .toRead, tags: ["Crime"])
        book.id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        book.categories = ["Fiction / Mystery & Detective"]
        let collection = BookCollection(name: "Favorites")

        let unchangedSignature = TagsIndexBuilder.suggestionTaskSignature(books: [book])
        CollectionMembershipMutation.add(book, to: collection, now: Date(timeIntervalSince1970: 1_000))
        let membershipOnlySignature = TagsIndexBuilder.suggestionTaskSignature(books: [book])

        book.tags.append("Noir")
        let changedTagsSignature = TagsIndexBuilder.suggestionTaskSignature(books: [book])

        #expect(unchangedSignature == membershipOnlySignature)
        #expect(unchangedSignature != changedTagsSignature)
    }

    @Test func suggestionsPreferPrefixMatchesAndExcludeSelectedTags() {
        let tagCounts = [
            TagsIndexBuilder.TagCount(tag: "Crime", count: 5),
            TagsIndexBuilder.TagCount(tag: "Space Opera", count: 4),
            TagsIndexBuilder.TagCount(tag: "Cosy Crime", count: 3),
            TagsIndexBuilder.TagCount(tag: "Microhistory", count: 2)
        ]

        let suggestions = TagsIndexBuilder.autocompleteSuggestions(
            query: "cri",
            selectedTags: ["crime"],
            tagCounts: tagCounts
        )

        #expect(suggestions == ["Cosy Crime", "Microhistory"])
    }

    @Test func suggestionsReturnEmptyForBlankQueryOrEmptyCounts() {
        let blankQuery = TagsIndexBuilder.autocompleteSuggestions(
            query: "   ",
            selectedTags: [],
            tagCounts: [TagsIndexBuilder.TagCount(tag: "Noir", count: 1)]
        )
        let emptyCounts = TagsIndexBuilder.autocompleteSuggestions(
            query: "no",
            selectedTags: [],
            tagCounts: []
        )

        #expect(blankQuery.isEmpty)
        #expect(emptyCounts.isEmpty)
    }
}