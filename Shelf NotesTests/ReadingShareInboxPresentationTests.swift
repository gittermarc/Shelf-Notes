import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingShareInboxPresentationTests {
    @Test func presentationDescribesMatchedBookLink() {
        let item = ReadingShareInboxItem(
            payload: ReadingSharePayload(
                kind: .bookLink,
                provider: .kindle,
                title: "Kindle Demo",
                canonicalURL: "https://www.amazon.de/dp/B08TEST123",
                providerItemIdentifier: "B08TEST123"
            )
        )
        let match = ReadingShareBookMatch(
            bookID: UUID(),
            title: "Kindle Demo",
            author: "Author",
            confidence: .confirmed,
            reason: "Bestehende externe Referenz"
        )
        let state = ReadingShareInboxPresentationBuilder.make(item: item, resolution: .matched(match))

        #expect(state.title == "Kindle Demo")
        #expect(state.providerTitle == "Kindle")
        #expect(state.subtitle == "https://www.amazon.de/dp/B08TEST123")
        #expect(state.previewText == nil)
    }

    @Test func presentationDescribesTextPayloadAndImportState() {
        let item = ReadingShareInboxItem(
            payload: ReadingSharePayload(kind: .text, provider: .other, title: nil, text: "Nur Text")
        )
        let state = ReadingShareInboxPresentationBuilder.make(
            item: item,
            resolution: .needsImport(ReadingSharePreparedImport(query: "Nur Text", reason: "Text aus dem Share"))
        )

        #expect(state.title == "Geteilter Text")
        #expect(state.subtitle == "Notiz oder Textauswahl")
        #expect(state.previewText == "Nur Text")
    }
}
