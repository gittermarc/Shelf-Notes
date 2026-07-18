import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryWidgetMixedProgressTests {
    @Test func builderKeepsPagePayloadForPhysicalBooks() throws {
        let snapshot = makeWidgetSnapshot(
            record: LibraryWidgetBookRecord(
                id: fixedID(1),
                title: "Physical",
                statusRawValue: ReadingStatus.reading.rawValue,
                createdAt: timestamp,
                pageCount: 100,
                pagesRead: 40,
                mediumRawValue: ReadingMedium.physical.rawValue,
                providerRawValue: ReadingProvider.none.rawValue,
                progressUnitRawValue: ReadingProgressUnit.pages.rawValue
            )
        )
        let book = try #require(snapshot.currentBook)

        #expect(book.pageCount == 100)
        #expect(book.pagesRead == 40)
        #expect(book.remainingPages == 60)
        #expect(book.progressFraction == 0.4)
        #expect(book.progressUnitRawValue == ReadingProgressUnit.pages.rawValue)
    }

    @Test func builderUsesPercentageWithoutPagePayload() throws {
        let snapshot = makeWidgetSnapshot(
            record: LibraryWidgetBookRecord(
                id: fixedID(2),
                title: "Kindle",
                statusRawValue: ReadingStatus.reading.rawValue,
                createdAt: timestamp,
                pageCount: 500,
                pagesRead: 200,
                progressFraction: 0.4,
                progressNativeValue: 40,
                mediumRawValue: ReadingMedium.ebook.rawValue,
                providerRawValue: ReadingProvider.kindle.rawValue,
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue
            )
        )
        let book = try #require(snapshot.currentBook)
        let presentation = LibraryWidgetSnapshotPresentation(snapshot: snapshot, now: timestamp)

        #expect(book.pageCount == nil)
        #expect(book.pagesRead == nil)
        #expect(book.remainingPages == nil)
        #expect(book.progressFraction == 0.4)
        #expect(book.progressNativeValue == 40)
        #expect(presentation.currentBookProgressText == "Lesestand 40 % · manuell")
        #expect(presentation.currentBookDetail.contains("Kindle"))
    }

    @Test func locatorWithoutPercentageNeverInventsProgressNumber() throws {
        let snapshot = makeWidgetSnapshot(
            record: LibraryWidgetBookRecord(
                id: fixedID(3),
                title: "Local EPUB",
                statusRawValue: ReadingStatus.reading.rawValue,
                createdAt: timestamp,
                pageCount: 300,
                pagesRead: 120,
                progressLocator: "Kapitel 7",
                mediumRawValue: ReadingMedium.ebook.rawValue,
                providerRawValue: ReadingProvider.localFile.rawValue,
                progressUnitRawValue: ReadingProgressUnit.locator.rawValue
            )
        )
        let book = try #require(snapshot.currentBook)
        let presentation = LibraryWidgetSnapshotPresentation(snapshot: snapshot, now: timestamp)

        #expect(book.pageCount == nil)
        #expect(book.pagesRead == nil)
        #expect(book.progressFraction == nil)
        #expect(presentation.currentBookProgressText == "Leseposition: Kapitel 7")
        #expect(presentation.currentBookProgressText?.contains("%") == false)
    }

    @Test func noneProgressCarriesNoSyntheticProgress() throws {
        let snapshot = makeWidgetSnapshot(
            record: LibraryWidgetBookRecord(
                id: fixedID(4),
                title: "Time Only",
                statusRawValue: ReadingStatus.reading.rawValue,
                createdAt: timestamp,
                pageCount: 300,
                pagesRead: 120,
                mediumRawValue: ReadingMedium.ebook.rawValue,
                providerRawValue: ReadingProvider.other.rawValue,
                progressUnitRawValue: ReadingProgressUnit.none.rawValue
            )
        )
        let book = try #require(snapshot.currentBook)
        let presentation = LibraryWidgetSnapshotPresentation(snapshot: snapshot, now: timestamp)

        #expect(book.pageCount == nil)
        #expect(book.pagesRead == nil)
        #expect(book.progressFraction == nil)
        #expect(presentation.currentBookProgressText == nil)
    }

    @Test func legacyBookPayloadDecodesWithoutNewSourceFields() throws {
        let legacy = LegacyBookSnapshot(
            id: fixedID(5),
            title: "Legacy",
            author: "Author",
            kind: .currentReading,
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 200,
            pagesRead: 50,
            remainingPages: 150,
            progressFraction: 0.25,
            referenceDate: timestamp,
            hasCover: false,
            coverRevision: nil
        )
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(LibraryWidgetBookSnapshot.self, from: data)
        let root = LibraryWidgetSnapshot(
            generatedAt: timestamp,
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0,
            currentBook: decoded
        )
        let presentation = LibraryWidgetSnapshotPresentation(snapshot: root, now: timestamp)

        #expect(decoded.mediumRawValue == nil)
        #expect(decoded.providerRawValue == nil)
        #expect(decoded.progressUnitRawValue == nil)
        #expect(presentation.currentBookProgressText == "50 von 200 Seiten · noch 150")
    }

    private var timestamp: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func makeWidgetSnapshot(record: LibraryWidgetBookRecord) -> LibraryWidgetSnapshot {
        LibraryWidgetSnapshotBuilder.make(
            books: [record],
            goals: [],
            recentActivity: .empty,
            activeBookID: record.id,
            generatedAt: timestamp
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

private struct LegacyBookSnapshot: Encodable {
    let id: UUID
    let title: String
    let author: String?
    let kind: LibraryWidgetShelfItemKind
    let statusRawValue: String
    let pageCount: Int?
    let pagesRead: Int?
    let remainingPages: Int?
    let progressFraction: Double?
    let referenceDate: Date?
    let hasCover: Bool
    let coverRevision: Int?
}
