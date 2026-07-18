import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSharePayloadParserTests {
    @Test func parsesAppleBooksLink() throws {
        let url = try #require(URL(string: "https://books.apple.com/de/book/demo/id123456789"))
        let payload = try ReadingSharePayloadParser.parse(title: "Demo", text: nil, url: url)

        #expect(payload.kind == .bookLink)
        #expect(payload.provider == .appleBooks)
        #expect(payload.providerItemIdentifier == "id123456789")
        #expect(payload.canonicalURL == "https://books.apple.com/de/book/demo/id123456789")
        #expect(payload.title == "Demo")
    }

    @Test func parsesKindleProductLink() throws {
        let url = try #require(URL(string: "https://www.amazon.de/dp/B08TEST123?tag=ignored"))
        let payload = try ReadingSharePayloadParser.parse(title: nil, text: nil, url: url)

        #expect(payload.kind == .bookLink)
        #expect(payload.provider == .kindle)
        #expect(payload.providerItemIdentifier == "B08TEST123")
    }

    @Test func parsesGoogleBooksLink() throws {
        let url = try #require(URL(string: "https://books.google.com/books?id=abc123"))
        let payload = try ReadingSharePayloadParser.parse(title: nil, text: nil, url: url)

        #expect(payload.kind == .bookLink)
        #expect(payload.provider == .googleBooks)
        #expect(payload.providerItemIdentifier == "abc123")
    }

    @Test func parsesGenericHTTPSBookLink() throws {
        let url = try #require(URL(string: "https://publisher.example/books/demo"))
        let payload = try ReadingSharePayloadParser.parse(title: "Publisher Demo", text: nil, url: url)

        #expect(payload.kind == .bookLink)
        #expect(payload.provider == .other)
        #expect(payload.canonicalURL == "https://publisher.example/books/demo")
    }

    @Test func parsesPlainTextAsNotePayload() throws {
        let payload = try ReadingSharePayloadParser.parse(
            title: "Notiz",
            text: "Ein markierter Gedanke ohne Link.",
            url: nil
        )

        #expect(payload.kind == .text)
        #expect(payload.provider == .other)
        #expect(payload.text == "Ein markierter Gedanke ohne Link.")
    }

    @Test func parsesTextTogetherWithURLAsHighlightPayload() throws {
        let url = try #require(URL(string: "https://books.apple.com/de/book/demo/id123456789"))
        let payload = try ReadingSharePayloadParser.parse(
            title: "Demo",
            text: "Das ist ein Highlight.",
            url: url
        )

        #expect(payload.kind == .textWithURL)
        #expect(payload.provider == .appleBooks)
        #expect(payload.text == "Das ist ein Highlight.")
    }

    @Test func extractsISBNCandidatesFromText() throws {
        let payload = try ReadingSharePayloadParser.parse(
            title: nil,
            text: "ISBN 978-3-16-148410-0",
            url: nil
        )

        #expect(payload.isbn13Candidates == ["9783161484100"])
    }

    @Test func rejectsUnsupportedURLSchemesAndPrivateHosts() throws {
        let customURL = try #require(URL(string: "kindle://book/B08TEST123"))
        #expect(throws: ReadingSharePayloadParserError.unsupportedURL) {
            try ReadingSharePayloadParser.parse(title: nil, text: nil, url: customURL)
        }

        let localURL = try #require(URL(string: "https://127.0.0.1/book"))
        #expect(throws: ReadingSharePayloadParserError.unsupportedURL) {
            try ReadingSharePayloadParser.parse(title: nil, text: nil, url: localURL)
        }
    }
}
