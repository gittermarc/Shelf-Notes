//
//  LibraryHomeSnapshotBuilder.swift
//  Shelf Notes
//
//  Pure builder for the Smart Shelf home snapshot.
//

import Foundation

extension LibraryView {
    nonisolated enum LibraryHomeSnapshotBuilder {
        static let defaultLaneLimit = 12

        static func makeSnapshot(
            source: LibrarySourceSnapshot,
            laneLimit: Int = defaultLaneLimit
        ) -> LibraryHomeSnapshot {
            makeSnapshot(books: source.books, laneLimit: laneLimit)
        }

        static func makeSnapshot(
            books: [LibrarySourceSnapshot.BookSnapshot],
            laneLimit: Int = defaultLaneLimit
        ) -> LibraryHomeSnapshot {
            guard books.isEmpty == false else { return .empty }

            return LibraryHomeSnapshot(
                continueReadingBookID: continueReadingBookID(in: books),
                quickStats: quickStats(in: books),
                lanes: lanes(in: books, laneLimit: laneLimit)
            )
        }

        private static func continueReadingBookID(
            in books: [LibrarySourceSnapshot.BookSnapshot]
        ) -> UUID? {
            let readingBooks = books.filter { $0.status == .reading }
            guard readingBooks.isEmpty == false else { return nil }

            let booksWithSessions = readingBooks.filter { $0.lastSessionAt != nil }
            if booksWithSessions.isEmpty == false {
                return booksWithSessions.sorted(by: compareContinueReadingWithSessions).first?.id
            }

            return readingBooks.sorted(by: compareRecentlyCreated).first?.id
        }

        private static func quickStats(in books: [LibrarySourceSnapshot.BookSnapshot]) -> [LibraryHomeStat] {
            let counts = LibraryDerivedStateBuilder.statusCounts(in: books)

            return [
                LibraryHomeStat(
                    id: "total",
                    title: "Gesamt",
                    value: books.count,
                    systemImage: "books.vertical"
                ),
                LibraryHomeStat(
                    id: ReadingStatus.reading.rawValue,
                    title: "Aktuell",
                    value: counts.reading,
                    systemImage: "book"
                ),
                LibraryHomeStat(
                    id: ReadingStatus.toRead.rawValue,
                    title: "Stapel",
                    value: counts.toRead,
                    systemImage: "bookmark"
                ),
                LibraryHomeStat(
                    id: ReadingStatus.finished.rawValue,
                    title: "Gelesen",
                    value: counts.finished,
                    systemImage: "checkmark.seal"
                )
            ]
        }

        private static func lanes(
            in books: [LibrarySourceSnapshot.BookSnapshot],
            laneLimit: Int
        ) -> [LibraryHomeLane] {
            let limit = max(1, laneLimit)
            let currentlyReadingIDs = limitedIDs(
                from: books.filter { $0.status == .reading }.sorted(by: compareActivity),
                limit: limit
            )
            let recentlyAddedIDs = limitedIDs(
                from: books.sorted(by: compareRecentlyCreated),
                limit: limit
            )
            let recentlyFinishedIDs = limitedIDs(
                from: books.filter { $0.status == .finished && readDate(for: $0) != nil }
                    .sorted(by: compareReadDate),
                limit: limit
            )
            let topRatedIDs = limitedIDs(
                from: books.filter { $0.status == .finished && $0.userRatingAverage1 != nil }
                    .sorted(by: compareRating),
                limit: limit
            )

            return [
                LibraryHomeLane(
                    kind: .currentlyReading,
                    title: "Gerade dabei",
                    systemImage: "book.pages",
                    bookIDs: currentlyReadingIDs
                ),
                LibraryHomeLane(
                    kind: .recentlyAdded,
                    title: "Neu im Regal",
                    systemImage: "sparkles.rectangle.stack",
                    bookIDs: recentlyAddedIDs
                ),
                LibraryHomeLane(
                    kind: .recentlyFinished,
                    title: "Zuletzt beendet",
                    systemImage: "checkmark.seal",
                    bookIDs: recentlyFinishedIDs
                ),
                LibraryHomeLane(
                    kind: .topRated,
                    title: "Top bewertet",
                    systemImage: "star",
                    bookIDs: topRatedIDs
                )
            ].filter { $0.bookIDs.isEmpty == false }
        }

        private static func limitedIDs(
            from books: [LibrarySourceSnapshot.BookSnapshot],
            limit: Int
        ) -> [UUID] {
            Array(books.prefix(limit).map(\.id))
        }

        private static func compareContinueReadingWithSessions(
            _ lhs: LibrarySourceSnapshot.BookSnapshot,
            _ rhs: LibrarySourceSnapshot.BookSnapshot
        ) -> Bool {
            let leftDate = lhs.lastSessionAt ?? .distantPast
            let rightDate = rhs.lastSessionAt ?? .distantPast

            if leftDate != rightDate {
                return leftDate > rightDate
            }

            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        private static func compareActivity(
            _ lhs: LibrarySourceSnapshot.BookSnapshot,
            _ rhs: LibrarySourceSnapshot.BookSnapshot
        ) -> Bool {
            let leftDate = LibraryDerivedStateBuilder.activityKeyDate(lhs)
            let rightDate = LibraryDerivedStateBuilder.activityKeyDate(rhs)

            if leftDate != rightDate {
                return leftDate > rightDate
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        private static func compareRecentlyCreated(
            _ lhs: LibrarySourceSnapshot.BookSnapshot,
            _ rhs: LibrarySourceSnapshot.BookSnapshot
        ) -> Bool {
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        private static func compareReadDate(
            _ lhs: LibrarySourceSnapshot.BookSnapshot,
            _ rhs: LibrarySourceSnapshot.BookSnapshot
        ) -> Bool {
            let leftDate = readDate(for: lhs) ?? .distantPast
            let rightDate = readDate(for: rhs) ?? .distantPast

            if leftDate != rightDate {
                return leftDate > rightDate
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        private static func compareRating(
            _ lhs: LibrarySourceSnapshot.BookSnapshot,
            _ rhs: LibrarySourceSnapshot.BookSnapshot
        ) -> Bool {
            let leftRating = lhs.userRatingAverage1 ?? -1
            let rightRating = rhs.userRatingAverage1 ?? -1

            if leftRating != rightRating {
                return leftRating > rightRating
            }

            let leftDate = readDate(for: lhs) ?? lhs.createdAt
            let rightDate = readDate(for: rhs) ?? rhs.createdAt

            if leftDate != rightDate {
                return leftDate > rightDate
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        private static func readDate(for book: LibrarySourceSnapshot.BookSnapshot) -> Date? {
            LibraryDerivedStateBuilder.readKeyDate(book)
        }
    }
}
