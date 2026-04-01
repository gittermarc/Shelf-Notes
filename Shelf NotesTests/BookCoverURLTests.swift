import Foundation
import Testing
@testable import Shelf_Notes

struct BookCoverURLTests {

    @Test @MainActor func bestCoverPrefersLocalUserCoverWhenSyncedThumbnailIsMissing() {
        let book = Book(title: "The Stand")
        book.userCoverFileName = "cover.jpg"
        book.userCoverData = nil
        book.thumbnailURL = "https://example.com/remote.jpg"

        let best = book.bestCoverURLString

        #expect(best?.hasPrefix("file://") == true)
        #expect(best?.contains("cover.jpg") == true)
    }

    @Test @MainActor func bestCoverFallsBackFromThumbnailToCandidatesToOpenLibrary() {
        let candidateBook = Book(title: "Dune")
        candidateBook.thumbnailURL = "  "
        candidateBook.coverURLCandidates = ["http://example.com/candidate.jpg"]

        #expect(candidateBook.bestCoverURLString == .some("https://example.com/candidate.jpg"))

        let fallbackBook = Book(title: "Hyperion")
        fallbackBook.isbn13 = "978-0553283686"

        #expect(fallbackBook.bestCoverURLString == .some("https://covers.openlibrary.org/b/isbn/9780553283686-L.jpg?default=false"))
    }

    @Test @MainActor func coverCandidatesAreDeduplicatedAndBestFirst() {
        let book = Book(title: "Foundation")
        book.userCoverFileName = "user.jpg"
        book.thumbnailURL = "http://example.com/thumb.jpg"
        book.coverURLCandidates = [
            "https://example.com/thumb.jpg",
            "http://example.com/alt.jpg",
            "https://example.com/alt.jpg"
        ]
        book.isbn13 = "9780553293357"

        let candidates = book.coverCandidatesAll

        #expect(candidates.count == 6)
        #expect(candidates.first?.hasPrefix("file://") == true)
        #expect(candidates.dropFirst().first == .some("https://example.com/thumb.jpg"))
        #expect(candidates.contains("https://example.com/alt.jpg"))
        #expect(candidates.contains("https://covers.openlibrary.org/b/isbn/9780553293357-L.jpg?default=false"))
    }

    @Test @MainActor func persistResolvedCoverURLNormalizesMovesToFrontAndSkipsFileURLs() {
        let book = Book(title: "Snow Crash")
        book.coverURLCandidates = ["https://example.com/second.jpg", "https://example.com/first.jpg"]

        book.persistResolvedCoverURL("http://example.com/first.jpg")

        #expect(book.thumbnailURL == .some("https://example.com/first.jpg"))
        #expect(book.coverURLCandidates == ["https://example.com/first.jpg", "https://example.com/second.jpg"])

        book.persistResolvedCoverURL("file:///tmp/local.jpg")

        #expect(book.thumbnailURL == .some("https://example.com/first.jpg"))
        #expect(book.coverURLCandidates == ["https://example.com/first.jpg", "https://example.com/second.jpg"])
    }
}
