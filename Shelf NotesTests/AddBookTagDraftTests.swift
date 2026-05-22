import Foundation
import Testing
@testable import Shelf_Notes

struct AddBookTagDraftTests {

    @Test @MainActor func addTagsFromDraftNormalizesAndClearsInput() {
        let vm = AddBookViewModel()
        vm.tagDraft = " #Crime, C#, crime "

        vm.addTagsFromDraft()

        #expect(vm.tags == ["Crime", "C#"])
        #expect(vm.tagDraft.isEmpty)
    }

    @Test @MainActor func acceptingSuggestionAddsTagWithoutDuplicates() {
        let vm = AddBookViewModel()
        vm.tags = ["Noir"]

        vm.acceptTagSuggestion("noir")
        vm.acceptTagSuggestion("NYC")

        #expect(vm.tags == ["Noir", "NYC"])
    }

    @Test @MainActor func tagSuggestionSnapshotUsesDraftBookMetadata() {
        let vm = AddBookViewModel()
        vm.title = "  Test Book  "
        vm.author = "  Test Author  "
        vm.tags = ["Crime"]
        vm.categories = ["Fiction / Mystery & Detective"]
        vm.mainCategory = "Mystery"
        vm.status = .reading

        let snapshot = vm.tagSuggestionSnapshot()

        #expect(snapshot.title == "Test Book")
        #expect(snapshot.author == "Test Author")
        #expect(snapshot.tags == ["Crime"])
        #expect(snapshot.categories == ["Fiction / Mystery & Detective"])
        #expect(snapshot.mainCategory == "Mystery")
        #expect(snapshot.statusRawValue == ReadingStatus.reading.rawValue)
    }
}
