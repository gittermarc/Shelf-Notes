import Foundation
import Testing
@testable import Shelf_Notes

struct CoverPipelineSplitTests {

    @Test func diskCacheKeyIsStableAndKeepsExtension() {
        let url = URL(string: "https://example.com/covers/book.jpg?size=large")!

        let first = ImageDiskCacheKey.fileName(for: url)
        let second = ImageDiskCacheKey.fileName(for: url)

        #expect(first == second)
        #expect(first.hasSuffix(".jpg"))
    }

    @Test func diskCacheKeyChangesWithURLAndUsesFallbackExtension() {
        let first = ImageDiskCacheKey.fileName(for: URL(string: "https://example.com/covers/book")!)
        let second = ImageDiskCacheKey.fileName(for: URL(string: "https://example.com/covers/book?variant=2")!)

        #expect(first != second)
        #expect(first.hasSuffix(".img"))
        #expect(second.hasSuffix(".img"))
    }

    @Test func syncedThumbnailCacheKeyIsStableAndChangesWithData() {
        let bookID = UUID(uuidString: "A79B5C4F-CA99-4818-B7FD-676B5B1D7740")!
        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9])
        let changed = Data([1, 2, 3, 4, 5, 6, 7, 8, 10])

        let first = SyncedThumbnailCacheKey.make(bookID: bookID, data: data)
        let second = SyncedThumbnailCacheKey.make(bookID: bookID, data: data)
        let third = SyncedThumbnailCacheKey.make(bookID: bookID, data: changed)

        #expect(first == second)
        #expect(first != third)
        #expect(first.hasPrefix(bookID.uuidString))
    }

    @Test func coverCandidateSequenceTrimsDeduplicatesAndFindsPreferredIndex() {
        let sequence = CoverCandidateSequence([
            "  https://example.com/a.jpg  ",
            "https://EXAMPLE.com/a.jpg",
            "",
            "https://example.com/b.jpg"
        ])

        #expect(sequence.candidates == [
            "https://example.com/a.jpg",
            "https://example.com/b.jpg"
        ])
        #expect(sequence.initialIndex(preferredURLString: " HTTPS://example.com/B.jpg ") == 1)
        #expect(sequence.initialIndex(preferredURLString: "https://example.com/missing.jpg") == 0)
    }

    @Test func displayCandidatesKeepFileURLsAndAddUpgradedRemoteBeforeOriginal() {
        let fileURL = "file:///tmp/local-cover.jpg"
        let original = "https://books.google.com/books/content?id=abc&zoom=1"
        let upgraded = CoverThumbnailer.upgradedRemoteURLString(original, target: .display)

        let candidates = CoverDisplayCandidates.make(from: [
            "  \(fileURL)  ",
            original,
            upgraded
        ])

        #expect(candidates == [fileURL, upgraded, original])
    }

    @Test func preferredHighResURLKeepsExistingFallbackOrder() {
        let thumbnail = "https://books.google.com/books/content?id=thumb&zoom=1"
        let candidate = "https://books.google.com/books/content?id=candidate&zoom=1"

        let filePreferred = CoverDisplayCandidates.preferredHighResURLString(
            userCoverFileName: "local.jpg",
            thumbnailURL: thumbnail,
            coverURLCandidates: [candidate]
        )
        #expect(filePreferred?.hasPrefix("file://") == true)
        #expect(filePreferred?.contains("local.jpg") == true)

        let thumbnailPreferred = CoverDisplayCandidates.preferredHighResURLString(
            userCoverFileName: nil,
            thumbnailURL: "  \(thumbnail)  ",
            coverURLCandidates: [candidate]
        )
        #expect(thumbnailPreferred == CoverThumbnailer.upgradedRemoteURLString(thumbnail, target: .display))

        let candidatePreferred = CoverDisplayCandidates.preferredHighResURLString(
            userCoverFileName: nil,
            thumbnailURL: "  ",
            coverURLCandidates: [candidate]
        )
        #expect(candidatePreferred == CoverThumbnailer.upgradedRemoteURLString(candidate, target: .display))
    }
}
