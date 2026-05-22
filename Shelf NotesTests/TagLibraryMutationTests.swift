import Foundation
import Testing
@testable import Shelf_Notes

struct TagLibraryMutationTests {

    @Test func normalizationRemovesOnlyLeadingHashAndKeepsInnerHash() {
        #expect(normalizeTagString("  #Crime  ") == "Crime")
        #expect(normalizeTagString("#C#") == "C#")
        #expect(normalizeTagString("C#") == "C#")
        #expect(normalizeTagString("  #New   York  ") == "New York")
        #expect(normalizeTagString("#") == "")
    }

    @Test func renameUpdatesAllMatchingBooksAndDeduplicatesPerBook() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime", "Noir"]),
            makeSnapshot(2, tags: [" #crime ", "Crime Fiction", "Noir"]),
            makeSnapshot(3, tags: ["History"])
        ]

        let result = TagLibraryMutation.rename(
            tag: "#crime",
            to: " Crime Fiction ",
            in: snapshots
        )

        #expect(result.kind == .rename)
        #expect(result.sourceTags == ["crime"])
        #expect(result.targetTag == "Crime Fiction")
        #expect(result.changedBookIDs == [fixedID(1), fixedID(2)])
        #expect(result.changes[0].newTags == ["Crime Fiction", "Noir"])
        #expect(result.changes[1].newTags == ["Crime Fiction", "Noir"])
    }

    @Test func deleteRemovesTagFromAllMatchingBooksOnly() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime", "Noir"]),
            makeSnapshot(2, tags: ["crime", "History"]),
            makeSnapshot(3, tags: ["C#", "Programming"])
        ]

        let result = TagLibraryMutation.delete(tag: "Crime", in: snapshots)

        #expect(result.kind == .delete)
        #expect(result.targetTag == nil)
        #expect(result.changedBookIDs == [fixedID(1), fixedID(2)])
        #expect(result.changes[0].newTags == ["Noir"])
        #expect(result.changes[1].newTags == ["History"])
    }

    @Test func mergeMultipleSourceTagsIntoTargetAndDeduplicates() {
        let snapshots = [
            makeSnapshot(1, tags: ["SciFi", "Science Fiction", "Space"]),
            makeSnapshot(2, tags: ["C#", "Sci-Fi"]),
            makeSnapshot(3, tags: ["Science Fiction"]),
            makeSnapshot(4, tags: ["History"])
        ]

        let result = TagLibraryMutation.merge(
            sourceTags: ["SciFi", "Sci-Fi", "scifi"],
            into: "Science Fiction",
            in: snapshots
        )

        #expect(result.kind == .merge)
        #expect(result.sourceTags == ["SciFi", "Sci-Fi"])
        #expect(result.targetTag == "Science Fiction")
        #expect(result.changedBookIDs == [fixedID(1), fixedID(2)])
        #expect(result.changes[0].newTags == ["Science Fiction", "Space"])
        #expect(result.changes[1].newTags == ["C#", "Science Fiction"])
    }

    @Test func mergeCanNormalizeExistingTargetSpelling() {
        let snapshots = [
            makeSnapshot(1, tags: ["science fiction", "Space"]),
            makeSnapshot(2, tags: ["SciFi"])
        ]

        let result = TagLibraryMutation.merge(
            sourceTags: ["SciFi"],
            into: "Science Fiction",
            in: snapshots
        )

        #expect(result.changedBookIDs == [fixedID(1), fixedID(2)])
        #expect(result.changes[0].newTags == ["Science Fiction", "Space"])
        #expect(result.changes[1].newTags == ["Science Fiction"])
    }

    @Test func emptyInputsCreateNoChanges() {
        let snapshots = [makeSnapshot(1, tags: ["Crime"])]

        let rename = TagLibraryMutation.rename(tag: "Crime", to: " # ", in: snapshots)
        let delete = TagLibraryMutation.delete(tag: " # ", in: snapshots)
        let merge = TagLibraryMutation.merge(sourceTags: [" ", "#"], into: "Target", in: snapshots)

        #expect(!rename.hasChanges)
        #expect(!delete.hasChanges)
        #expect(!merge.hasChanges)
    }

    @Test func cSharpIsNotChangedWhenDeletingPlainCTag() {
        let snapshots = [
            makeSnapshot(1, tags: ["C#", "Programming"]),
            makeSnapshot(2, tags: ["C", "Language"])
        ]

        let result = TagLibraryMutation.delete(tag: "C", in: snapshots)

        #expect(result.changedBookIDs == [fixedID(2)])
        #expect(result.changes[0].newTags == ["Language"])
    }

    @Test @MainActor func applyWritesChangedTagsBackToBooks() {
        let first = Book(title: "First", tags: ["Crime"])
        let second = Book(title: "Second", tags: ["History"])
        first.id = fixedID(1)
        second.id = fixedID(2)

        let result = TagLibraryMutation.rename(
            tag: "Crime",
            to: "Krimi",
            in: TagLibraryMutation.makeSnapshots(books: [first, second])
        )

        let appliedCount = TagLibraryMutation.apply(result, to: [first, second])

        #expect(appliedCount == 1)
        #expect(first.tags == ["Krimi"])
        #expect(second.tags == ["History"])
    }

    private func makeSnapshot(_ value: Int, tags: [String]) -> TagLibraryMutationBookSnapshot {
        TagLibraryMutationBookSnapshot(id: fixedID(value), tags: tags)
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
