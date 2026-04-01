//
//  LibraryDerivedState.swift
//  Shelf Notes
//
//  Value-only input/output types for the Library derived state pipeline.
//

import Foundation

extension LibraryView {

    struct LibraryStatusCounts: Equatable {
        var toRead: Int
        var reading: Int
        var finished: Int

        static let zero = LibraryStatusCounts(toRead: 0, reading: 0, finished: 0)
    }

    struct AlphaSectionDescriptor: Equatable {
        let id: String
        let key: String
        let bookIDs: [UUID]
    }

    struct LibrarySourceSnapshot: Equatable {
        struct BookSnapshot: Equatable {
            let id: UUID
            let title: String
            let author: String
            let createdAt: Date
            let statusRawValue: String
            let tags: [String]
            let hasNotes: Bool
            let isbn13: String?
            let readFrom: Date?
            let readTo: Date?
            let userRatingAverage1: Double?

            init(book: Book) {
                id = book.id
                title = book.title
                author = book.author
                createdAt = book.createdAt
                statusRawValue = book.status.rawValue
                tags = book.tags
                hasNotes = book.notes.contains(where: { !$0.isWhitespace })
                isbn13 = book.isbn13
                readFrom = book.readFrom
                readTo = book.readTo
                userRatingAverage1 = book.userRatingAverage1
            }

            init(
                id: UUID = UUID(),
                title: String,
                author: String = "",
                createdAt: Date = .distantPast,
                statusRawValue: String = ReadingStatus.toRead.rawValue,
                tags: [String] = [],
                hasNotes: Bool = false,
                isbn13: String? = nil,
                readFrom: Date? = nil,
                readTo: Date? = nil,
                userRatingAverage1: Double? = nil
            ) {
                self.id = id
                self.title = title
                self.author = author
                self.createdAt = createdAt
                self.statusRawValue = statusRawValue
                self.tags = tags
                self.hasNotes = hasNotes
                self.isbn13 = isbn13
                self.readFrom = readFrom
                self.readTo = readTo
                self.userRatingAverage1 = userRatingAverage1
            }

            var status: ReadingStatus {
                ReadingStatus.fromPersisted(statusRawValue) ?? .toRead
            }
        }

        let signature: Int
        let books: [BookSnapshot]

        init(signature: Int, books: [BookSnapshot]) {
            self.signature = signature
            self.books = books
        }

        init(books: [Book]) {
            let snapshots = books.map(BookSnapshot.init(book:))
            self.init(signature: Self.computeSignature(snapshot: snapshots), books: snapshots)
        }

        static let empty = LibrarySourceSnapshot(signature: 0, books: [])

        static func taskSignature(books: [Book]) -> Int {
            var xorAggregate = 0
            var sumAggregate = 0

            for book in books {
                var hasher = Hasher()
                hasher.combine(book.id)
                hasher.combine(book.title)
                hasher.combine(book.author)
                hasher.combine(dayStamp(book.createdAt))
                hasher.combine(book.status.rawValue)
                hasher.combine(book.tags.count)
                for tag in book.tags {
                    hasher.combine(tag.lowercased())
                }
                hasher.combine(book.notes.contains(where: { !$0.isWhitespace }))
                hasher.combine(book.isbn13)
                hasher.combine(dayStamp(book.readFrom))
                hasher.combine(dayStamp(book.readTo))
                hasher.combine(ratingBucket(book.userRatingAverage1))

                let bookHash = hasher.finalize()
                xorAggregate ^= bookHash
                sumAggregate &+= bookHash
            }

            var signatureHasher = Hasher()
            signatureHasher.combine(books.count)
            signatureHasher.combine(xorAggregate)
            signatureHasher.combine(sumAggregate)
            return signatureHasher.finalize()
        }

        static func computeSignature(snapshot: [BookSnapshot]) -> Int {
            var xorAggregate = 0
            var sumAggregate = 0

            for book in snapshot {
                var hasher = Hasher()
                hasher.combine(book.id)
                hasher.combine(book.title)
                hasher.combine(book.author)
                hasher.combine(dayStamp(book.createdAt))
                hasher.combine(book.statusRawValue)
                hasher.combine(book.tags.count)
                for tag in book.tags {
                    hasher.combine(tag.lowercased())
                }
                hasher.combine(book.hasNotes)
                hasher.combine(book.isbn13)
                hasher.combine(dayStamp(book.readFrom))
                hasher.combine(dayStamp(book.readTo))
                hasher.combine(ratingBucket(book.userRatingAverage1))

                let bookHash = hasher.finalize()
                xorAggregate ^= bookHash
                sumAggregate &+= bookHash
            }

            var signatureHasher = Hasher()
            signatureHasher.combine(snapshot.count)
            signatureHasher.combine(xorAggregate)
            signatureHasher.combine(sumAggregate)
            return signatureHasher.finalize()
        }

        private static func dayStamp(_ date: Date) -> Int {
            Int(date.timeIntervalSince1970 / 86_400)
        }

        private static func dayStamp(_ date: Date?) -> Int {
            guard let date else { return -1 }
            return dayStamp(date)
        }

        private static func ratingBucket(_ value: Double?) -> Int {
            guard let value else { return -1 }
            return Int((value * 10).rounded())
        }
    }

    struct LibraryDerivedInput: Hashable {
        let searchText: String
        let selectedStatusRawValue: String?
        let selectedTag: String?
        let onlyWithNotes: Bool
        let sortField: SortField
        let sortAscending: Bool
        let buildsAlphaSections: Bool
    }

    struct LibraryDerivedInputToken: Hashable {
        let sourceSignature: Int
        let input: LibraryDerivedInput
    }

    struct LibraryDerivedState: Equatable {
        let token: LibraryDerivedInputToken
        let displayedBookIDs: [UUID]
        let counts: LibraryStatusCounts
        let alphaSections: [AlphaSectionDescriptor]
        let alphaLetters: [String]

        static let empty = LibraryDerivedState(
            token: LibraryDerivedInputToken(
                sourceSignature: 0,
                input: LibraryDerivedInput(
                    searchText: "",
                    selectedStatusRawValue: nil,
                    selectedTag: nil,
                    onlyWithNotes: false,
                    sortField: .createdAt,
                    sortAscending: false,
                    buildsAlphaSections: false
                )
            ),
            displayedBookIDs: [],
            counts: .zero,
            alphaSections: [],
            alphaLetters: []
        )
    }
}
