import Foundation
import Testing
@testable import Shelf_Notes

struct CSVExportBuilderTests {

    @Test @MainActor func exportContainsTitleAndISBN() throws {
        let book = Book(title: "The Hobbit")
        book.isbn13 = "9780261103344"

        let data = CSVExportBuilder.data(from: [book])
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(text.contains("The Hobbit,9780261103344"))
    }

    @Test @MainActor func exportHeaderRemainsStable() throws {
        let data = CSVExportBuilder.data(from: [])
        let text = try #require(String(data: data, encoding: .utf8))
        let firstLine = try #require(text.split(separator: "\n", omittingEmptySubsequences: true).first)

        #expect(String(firstLine) == "title,isbn13")
    }
}
