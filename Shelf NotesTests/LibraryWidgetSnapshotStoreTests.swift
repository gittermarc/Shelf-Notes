import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryWidgetSnapshotStoreTests {
    @Test func storeRoundTripsSnapshotJSON() throws {
        let directory = temporaryDirectory()
        let store = LibraryWidgetSnapshotStore(directoryURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 3,
            readBooks: 1,
            readingBooks: 1,
            wantToReadBooks: 1,
            currentBook: LibraryWidgetBookSnapshot(
                id: fixedID(1),
                title: "Dune",
                author: "Frank Herbert",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                pageCount: 400,
                pagesRead: 120,
                remainingPages: 280,
                progressFraction: 0.3,
                referenceDate: Date(timeIntervalSince1970: 900),
                hasCover: true,
                coverRevision: 42
            ),
            yearlyGoal: LibraryWidgetYearlyGoalSnapshot(
                year: 2026,
                targetCount: 12,
                finishedCount: 1
            ),
            last7DaysReadingMinutes: 50,
            last7DaysReadingDays: 2,
            currentReadingStreakDays: 2,
            recentShelfItems: []
        )

        #expect(store.save(snapshot))
        let loaded = try #require(store.load())

        #expect(loaded == snapshot)
        #expect(store.snapshotFileURL?.lastPathComponent == LibraryWidgetSnapshotStore.fileName)
    }

    @Test func storeReturnsNilForMissingSnapshot() {
        let directory = temporaryDirectory()
        let store = LibraryWidgetSnapshotStore(directoryURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(store.load() == nil)
    }

    @Test func storeReturnsNilForCorruptSnapshotJSON() throws {
        let directory = temporaryDirectory()
        let store = LibraryWidgetSnapshotStore(directoryURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = try #require(store.snapshotFileURL)
        try Data("not-json".utf8).write(to: url)

        #expect(store.load() == nil)
    }

    @Test func storeReturnsNilForFutureSnapshotSchema() {
        let directory = temporaryDirectory()
        let store = LibraryWidgetSnapshotStore(directoryURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = LibraryWidgetSnapshot(
            schemaVersion: LibraryWidgetSnapshot.currentSchemaVersion + 1,
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0
        )

        #expect(store.save(snapshot))
        #expect(store.load() == nil)
    }

    @Test func renderableContentComparisonIgnoresGeneratedAtOnly() {
        let first = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0
        )
        let second = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 2_000),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0
        )
        let changed = LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 2_000),
            state: .ready,
            totalBooks: 2,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 1
        )

        #expect(first.hasSameRenderableContent(as: second))
        #expect(!first.hasSameRenderableContent(as: changed))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryWidgetSnapshotStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
