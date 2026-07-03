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
