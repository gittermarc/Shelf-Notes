import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingProviderLaunchPolicyTests {
    @Test func appleBooksLaunchPolicyAllowsOnlyPublicHTTPSBookHosts() throws {
        let allowed = try #require(
            ReadingProviderLaunchPolicy.validatedReadingURL(
                rawString: "https://books.apple.com/de/book/demo/id123456789",
                provider: .appleBooks
            )
        )
        #expect(allowed.host == "books.apple.com")

        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "ibooks://assetid/123", provider: .appleBooks) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "http://books.apple.com/de/book/demo/id123", provider: .appleBooks) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "https://example.com/de/book/demo/id123", provider: .appleBooks) == nil)
    }

    @Test func kindleLaunchPolicyAllowsAmazonReadingDestinationsAndRejectsPrivateSchemes() throws {
        let product = try #require(
            ReadingProviderLaunchPolicy.validatedReadingURL(
                rawString: "https://www.amazon.de/dp/B012345678",
                provider: .kindle
            )
        )
        #expect(product.host == "www.amazon.de")

        let cloudReader = try #require(
            ReadingProviderLaunchPolicy.validatedReadingURL(
                rawString: "https://read.amazon.com/notebook",
                provider: .kindle
            )
        )
        #expect(cloudReader.host == "read.amazon.com")

        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "kindle://book?action=open", provider: .kindle) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "https://evil.example/dp/B012345678", provider: .kindle) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "https://amazon.evil.example/dp/B012345678", provider: .kindle) == nil)
    }

    @Test func otherProviderAllowsOnlyPublicHTTPSLinks() throws {
        let other = try #require(
            ReadingProviderLaunchPolicy.validatedReadingURL(
                rawString: "https://reader.example/books/1",
                provider: .other
            )
        )
        #expect(other.host == "reader.example")

        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "file:///tmp/book.epub", provider: .other) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "http://reader.example/books/1", provider: .other) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "https://localhost/books/1", provider: .other) == nil)
        #expect(ReadingProviderLaunchPolicy.validatedReadingURL(rawString: "https://192.168.1.12/books/1", provider: .other) == nil)
    }

    @Test func decisionReportsMissingAndBlockedReadingLinks() {
        let missing = ReadingProviderLaunchPolicy.decision(provider: .kindle, references: [])
        if case .missingReadingLink(let guidance) = missing {
            #expect(guidance.provider == .kindle)
            #expect(guidance.message.contains("Timer läuft"))
        } else {
            Issue.record("Kindle companion start without reference should return guidance.")
        }

        let blocked = ReadingProviderLaunchPolicy.decision(
            provider: .appleBooks,
            references: [
                ReadingProviderLaunchReference(
                    provider: .appleBooks,
                    canonicalURL: "https://example.com/book"
                )
            ]
        )
        if case .blocked(let message) = blocked {
            #expect(message.contains("HTTPS"))
        } else {
            Issue.record("Invalid Apple Books reference should be blocked.")
        }
    }

    @Test @MainActor func bookExternalReferencesAreUsedWithoutMergingProviders() throws {
        let book = Book(title: "Linked", status: .reading)
        let appleReference = BookExternalReference(
            book: book,
            provider: .appleBooks,
            providerItemIdentifier: "apple-1",
            canonicalURL: "https://books.apple.com/de/book/demo/id123456789"
        )
        let kindleReference = BookExternalReference(
            book: book,
            provider: .kindle,
            providerItemIdentifier: "kindle-1",
            canonicalURL: "https://www.amazon.de/dp/B012345678"
        )
        book.externalReferencesSafe = [appleReference, kindleReference]

        #expect(book.readingProviderLaunchReferences.map(\.provider) == [.appleBooks, .kindle])
        #expect(book.hasValidReadingLink(for: .appleBooks))
        #expect(book.hasValidReadingLink(for: .kindle))
        #expect(!book.hasValidReadingLink(for: .other))

        let appleLaunchReference = try #require(book.readingProviderLaunchReferences.first { $0.provider == .appleBooks })
        #expect(appleLaunchReference.providerItemIdentifier == "apple-1")
    }
}