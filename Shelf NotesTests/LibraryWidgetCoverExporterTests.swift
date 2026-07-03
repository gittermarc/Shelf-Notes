import Foundation
import Testing
@testable import Shelf_Notes

#if canImport(UIKit)
import UIKit
#endif

struct LibraryWidgetCoverExporterTests {
    @Test @MainActor func exporterWritesDisplayedCoverAndMarksItAvailable() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let book = Book(title: "Covered", author: "Author", status: .reading)
        book.id = fixedID(1)
        book.userCoverData = try #require(testJPEGData())

        let snapshot = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0,
            currentBook: LibraryWidgetBookSnapshot(
                id: book.id,
                title: "Covered",
                author: "Author",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                hasCover: true,
                coverRevision: 1
            )
        )

        let normalized = LibraryWidgetCoverExporter.exportCoversAndUpdateAvailability(
            in: snapshot,
            books: [book],
            directoryURLProvider: { directory }
        )

        let coverURL = LibraryWidgetCoverFilePolicy.fileURL(bookID: book.id, in: directory)
        #expect(FileManager.default.fileExists(atPath: coverURL.path))
        #expect(normalized.currentBook?.hasCover == true)
        #expect(normalized.currentBook?.coverRevision == 1)
    }

    @Test @MainActor func exporterTurnsMissingCoverIntoWidgetFallback() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let book = Book(title: "Missing Cover", author: "Author", status: .reading)
        book.id = fixedID(2)

        let snapshot = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0,
            currentBook: LibraryWidgetBookSnapshot(
                id: book.id,
                title: "Missing Cover",
                author: "Author",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                hasCover: true,
                coverRevision: 1
            )
        )

        let normalized = LibraryWidgetCoverExporter.exportCoversAndUpdateAvailability(
            in: snapshot,
            books: [book],
            directoryURLProvider: { directory }
        )

        #expect(normalized.currentBook?.hasCover == false)
        #expect(normalized.currentBook?.coverRevision == nil)
    }

    @Test @MainActor func cleanupRemovesOnlyUnusedWidgetCovers() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let keptID = fixedID(1)
        let removedID = fixedID(2)
        let coverDirectory = LibraryWidgetCoverFilePolicy.directoryURL(in: directory)
        try FileManager.default.createDirectory(at: coverDirectory, withIntermediateDirectories: true)

        let keptURL = LibraryWidgetCoverFilePolicy.fileURL(bookID: keptID, in: directory)
        let removedURL = LibraryWidgetCoverFilePolicy.fileURL(bookID: removedID, in: directory)
        let liveActivityLikeURL = coverDirectory.appendingPathComponent("live_activity_cover_\(removedID.uuidString).jpg")
        try Data("kept".utf8).write(to: keptURL)
        try Data("removed".utf8).write(to: removedURL)
        try Data("live".utf8).write(to: liveActivityLikeURL)

        LibraryWidgetCoverExporter.cleanupUnusedCovers(
            keeping: [keptID],
            containerURL: directory
        )

        #expect(FileManager.default.fileExists(atPath: keptURL.path))
        #expect(!FileManager.default.fileExists(atPath: removedURL.path))
        #expect(FileManager.default.fileExists(atPath: liveActivityLikeURL.path))
    }

    @Test @MainActor func exporterCleansAllWidgetCoversWhenSnapshotDoesNotUseCovers() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let staleID = fixedID(9)
        let coverDirectory = LibraryWidgetCoverFilePolicy.directoryURL(in: directory)
        try FileManager.default.createDirectory(at: coverDirectory, withIntermediateDirectories: true)
        let staleURL = LibraryWidgetCoverFilePolicy.fileURL(bookID: staleID, in: directory)
        try Data("stale".utf8).write(to: staleURL)

        let snapshot = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0,
            currentBook: LibraryWidgetBookSnapshot(
                id: staleID,
                title: "Private",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                hasCover: false
            )
        )

        _ = LibraryWidgetCoverExporter.exportCoversAndUpdateAvailability(
            in: snapshot,
            books: [],
            directoryURLProvider: { directory }
        )

        #expect(!FileManager.default.fileExists(atPath: staleURL.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryWidgetCoverExporterTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }

    private func testJPEGData() -> Data? {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 18))
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            context.cgContext.setFillColor(UIColor.systemBrown.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 12, height: 18))
        }
        #else
        return nil
        #endif
    }
}
