import Testing
@testable import Shelf_Notes

struct BookExternalReferenceFactoryTests {
    @Test @MainActor func googleBooksReferenceUsesProviderIdentifierAndValidatedCanonicalURL() throws {
        let book = Book(title: "Google", status: .toRead)
        let reference = try #require(
            BookExternalReferenceFactory.googleBooksReference(
                for: book,
                volumeID: " volume-123 ",
                canonicalURL: "https://books.google.com/books?id=volume-123"
            )
        )

        #expect(reference.provider == .googleBooks)
        #expect(reference.providerItemIdentifier == "volume-123")
        #expect(reference.canonicalURL == "https://books.google.com/books?id=volume-123")
        #expect(reference.book?.id == book.id)
    }

    @Test @MainActor func googleBooksReferenceDropsInvalidCanonicalURLWithoutInventingProviderFields() throws {
        let book = Book(title: "Invalid", status: .toRead)
        let reference = try #require(
            BookExternalReferenceFactory.googleBooksReference(
                for: book,
                volumeID: "volume-456",
                canonicalURL: "https://example.com/books?id=volume-456"
            )
        )

        #expect(reference.provider == .googleBooks)
        #expect(reference.providerItemIdentifier == "volume-456")
        #expect(reference.canonicalURL == nil)
    }

    @Test @MainActor func googleBooksReferenceRequiresProviderIdentifier() {
        let book = Book(title: "Missing", status: .toRead)
        let reference = BookExternalReferenceFactory.googleBooksReference(
            for: book,
            volumeID: "  ",
            canonicalURL: "https://books.google.com/books?id=missing"
        )

        #expect(reference == nil)
    }
}