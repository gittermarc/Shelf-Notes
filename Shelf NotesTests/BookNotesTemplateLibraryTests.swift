import Testing
@testable import Shelf_Notes

struct BookNotesTemplateLibraryTests {
    @Test func applyingPromptToEmptyTextUsesSnippetAsStartingPoint() {
        let result = BookNotesInsertion.applying(template: BookNotesTemplate.prompts[0], to: "")
        #expect(result == "Gedanke:\n")
    }

    @Test func applyingPromptToExistingTextAddsReadableSpacing() {
        let result = BookNotesInsertion.applying(template: BookNotesTemplate.prompts[1], to: "Schon da")
        #expect(result == "Schon da\n\nZitat:\n“”\n")
    }

    @Test func spacerTemplateAvoidsAddingInfiniteBlankLines() {
        let once = BookNotesInsertion.applying(template: BookNotesTemplate.toolbarActions[3], to: "Text")
        let twice = BookNotesInsertion.applying(template: BookNotesTemplate.toolbarActions[3], to: once)

        #expect(once == "Text\n\n")
        #expect(twice == once)
    }
}
