//
//  LibraryDerivedState.swift
//  Shelf Notes
//
//  Value-only input/output types for the Library derived state pipeline.
//

import Foundation

extension LibraryView {

    nonisolated struct LibrarySourceSignature: Equatable, Hashable, Sendable {
        let rawValue: Int

        static let empty = LibrarySourceSignature(rawValue: 0)

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        init(bookSnapshots: [LibrarySourceSnapshot.BookSnapshot]) {
            rawValue = LibrarySourceSnapshot.computeSignature(snapshot: bookSnapshots)
        }

        @MainActor init(books: [Book]) {
            rawValue = LibrarySourceSnapshot.taskSignature(books: books)
        }
    }

    nonisolated struct LibraryStatusCounts: Equatable {
        var toRead: Int
        var reading: Int
        var finished: Int

        static let zero = LibraryStatusCounts(toRead: 0, reading: 0, finished: 0)
    }

    nonisolated struct AlphaSectionDescriptor: Equatable {
        let id: String
        let key: String
        let bookIDs: [UUID]
    }

    nonisolated struct LibrarySourceSnapshot: Equatable {
        nonisolated struct BookSnapshot: Equatable {
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
            let pageCount: Int?
            let pagesReadTotal: Int
            let readingProgressFraction: Double?
            let lastSessionAt: Date?
            let hasCover: Bool
            let coverRevision: Int
            let hasUserRating: Bool
            let userRatingAverage1: Double?
            let isRereading: Bool
            let completedReadingAttemptCount: Int
            let currentReadingAttemptDisplayName: String?
            let collectionNames: [String]
            let searchTokens: [String]

            @MainActor init(book: Book) {
                let allSessions = book.readingSessionsSafe
                let progressSessions = ReadingAttemptSessionCoordinator.progressSessions(
                    for: book,
                    allSessions: allSessions
                )
                let pagesReadTotal = ReadingSessionLogging.pagesReadTotal(in: progressSessions)
                let pageCount = LibrarySourceSnapshot.normalizedPositiveInt(book.pageCount)
                let coverRevision = LibrarySourceSnapshot.coverRevision(for: book)
                let ratingAverage = LibrarySourceSnapshot.normalizedUserRatingAverage1(for: book)

                id = book.id
                title = book.title
                author = book.author
                createdAt = book.createdAt
                statusRawValue = book.statusRawValue
                tags = book.tags
                hasNotes = book.notes.contains(where: { !$0.isWhitespace })
                isbn13 = book.isbn13
                readFrom = book.readFrom
                readTo = book.readTo
                self.pageCount = pageCount
                self.pagesReadTotal = pagesReadTotal
                readingProgressFraction = ReadingSessionLogging.progressFraction(
                    status: book.status,
                    totalPages: pageCount,
                    sessions: progressSessions
                )
                lastSessionAt = LibrarySourceSnapshot.lastSessionDate(in: allSessions)
                hasCover = coverRevision > 0
                self.coverRevision = coverRevision
                hasUserRating = ratingAverage != nil
                userRatingAverage1 = ratingAverage
                isRereading = book.isRereading
                completedReadingAttemptCount = book.completedReadingAttemptCount
                currentReadingAttemptDisplayName = book.currentReadingAttemptDisplayName
                collectionNames = LibrarySourceSnapshot.normalizedCollectionNames(from: book.collectionsSafe)
                searchTokens = LibrarySourceSnapshot.makeSearchTokens(
                    title: book.title,
                    author: book.author,
                    isbn13: book.isbn13,
                    tags: book.tags
                )
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
                pageCount: Int? = nil,
                pagesReadTotal: Int = 0,
                readingProgressFraction: Double? = nil,
                lastSessionAt: Date? = nil,
                hasCover: Bool = false,
                coverRevision: Int = 0,
                hasUserRating: Bool? = nil,
                userRatingAverage1: Double? = nil,
                isRereading: Bool = false,
                completedReadingAttemptCount: Int = 0,
                currentReadingAttemptDisplayName: String? = nil,
                collectionNames: [String] = [],
                searchTokens: [String]? = nil
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
                self.pageCount = LibrarySourceSnapshot.normalizedPositiveInt(pageCount)
                self.pagesReadTotal = max(0, pagesReadTotal)
                self.readingProgressFraction = LibrarySourceSnapshot.normalizedProgressFraction(readingProgressFraction)
                self.lastSessionAt = lastSessionAt
                self.hasCover = hasCover || coverRevision > 0
                self.coverRevision = max(0, coverRevision)
                self.hasUserRating = hasUserRating ?? (userRatingAverage1 != nil)
                self.userRatingAverage1 = userRatingAverage1
                self.isRereading = isRereading
                self.completedReadingAttemptCount = max(0, completedReadingAttemptCount)
                self.currentReadingAttemptDisplayName = currentReadingAttemptDisplayName
                self.collectionNames = collectionNames
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                if let searchTokens {
                    self.searchTokens = LibrarySourceSnapshot.normalizedSearchTokens(searchTokens)
                } else {
                    self.searchTokens = LibrarySourceSnapshot.makeSearchTokens(
                        title: title,
                        author: author,
                        isbn13: isbn13,
                        tags: tags
                    )
                }
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

        @MainActor init(books: [Book]) {
            let snapshots = books.map(BookSnapshot.init(book:))
            self.init(signature: Self.computeSignature(snapshot: snapshots), books: snapshots)
        }

        static let empty = LibrarySourceSnapshot(signature: 0, books: [])

        @MainActor static func taskSignature(books: [Book]) -> Int {
            let snapshots = books.map(BookSnapshot.init(book:))
            return computeSignature(snapshot: snapshots)
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
                hasher.combine(book.pageCount)
                hasher.combine(book.pagesReadTotal)
                hasher.combine(progressBucket(book.readingProgressFraction))
                hasher.combine(timestampStamp(book.lastSessionAt))
                hasher.combine(book.hasCover)
                hasher.combine(book.coverRevision)
                hasher.combine(book.hasUserRating)
                hasher.combine(ratingBucket(book.userRatingAverage1))
                hasher.combine(book.isRereading)
                hasher.combine(book.completedReadingAttemptCount)
                hasher.combine(book.currentReadingAttemptDisplayName)
                for collectionName in book.collectionNames {
                    hasher.combine(collectionName.lowercased())
                }

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

        private static func timestampStamp(_ date: Date?) -> Int {
            guard let date else { return -1 }
            return Int(date.timeIntervalSince1970.rounded())
        }

        private static func ratingBucket(_ value: Double?) -> Int {
            guard let value else { return -1 }
            return Int((value * 10).rounded())
        }

        private static func progressBucket(_ value: Double?) -> Int {
            guard let value else { return -1 }
            return Int((value * 1_000).rounded())
        }

        static func normalizedPositiveInt(_ rawValue: Int?) -> Int? {
            guard let rawValue, rawValue > 0 else { return nil }
            return rawValue
        }

        static func normalizedProgressFraction(_ rawValue: Double?) -> Double? {
            guard let rawValue else { return nil }
            return min(1.0, max(0.0, rawValue))
        }

        static func lastSessionDate(in sessions: [ReadingSession]) -> Date? {
            sessions.map(\.startedAt).max()
        }

        static func normalizedCollectionNames(from collections: [BookCollection]) -> [String] {
            collections
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        static func coverRevision(for book: Book) -> Int {
            var hasher = Hasher()
            var hasAnyCover = false

            if let data = book.userCoverData, data.isEmpty == false {
                hasAnyCover = true
                hasher.combine("userCoverData")
                hasher.combine(data.count)
                hasher.combine(data)
            }

            if let fileName = normalizedNonEmptyString(book.userCoverFileName) {
                hasAnyCover = true
                hasher.combine("userCoverFileName")
                hasher.combine(fileName)
            }

            if let thumbnailURL = normalizedNonEmptyString(book.thumbnailURL) {
                hasAnyCover = true
                hasher.combine("thumbnailURL")
                hasher.combine(thumbnailURL)
            }

            let candidates = book.coverURLCandidates
                .compactMap(normalizedNonEmptyString)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            if candidates.isEmpty == false {
                hasAnyCover = true
                hasher.combine("coverURLCandidates")
                for candidate in candidates {
                    hasher.combine(candidate)
                }
            }

            guard hasAnyCover else { return 0 }
            let finalized = hasher.finalize()
            if finalized == Int.min {
                return Int.max
            }
            return max(1, abs(finalized))
        }

        private static func normalizedNonEmptyString(_ rawValue: String?) -> String? {
            guard let rawValue else { return nil }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        static func makeSearchTokens(
            title: String,
            author: String,
            isbn13: String?,
            tags: [String]
        ) -> [String] {
            var tokens: [String] = []
            tokens.reserveCapacity(3 + tags.count)

            appendSearchToken(title, to: &tokens)
            appendSearchToken(author, to: &tokens)
            if let isbn13 {
                appendSearchToken(isbn13, to: &tokens)
            }
            for tag in tags {
                appendSearchToken(tag, to: &tokens)
            }

            return tokens
        }

        private static func appendSearchToken(_ value: String, to tokens: inout [String]) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            tokens.append(normalizedSearchValue(trimmed))
        }

        static func normalizedSearchTokens(_ values: [String]) -> [String] {
            values.compactMap { value in
                let normalized = normalizedSearchValue(value)
                return normalized.isEmpty ? nil : normalized
            }
        }

        static func normalizedSearchValue(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        private static func normalizedUserRatingAverage1(for book: Book) -> Double? {
            let values = [
                book.userRatingPlot,
                book.userRatingCharacters,
                book.userRatingWritingStyle,
                book.userRatingAtmosphere,
                book.userRatingGenreFit,
                book.userRatingPresentation
            ].filter { $0 > 0 }

            guard values.isEmpty == false else { return nil }

            let sum = values.reduce(0, +)
            let average = Double(sum) / Double(values.count)
            return (average * 10).rounded() / 10
        }
    }

    nonisolated struct LibraryDerivedInput: Hashable {
        let searchText: String
        let normalizedSearchText: String
        let selectedStatusRawValue: String?
        let selectedTag: String?
        let selectedCollectionName: String?
        let onlyWithNotes: Bool
        let smartFilter: LibrarySmartFilter?
        let longInactiveCutoff: Date?
        let sortField: SortField
        let sortAscending: Bool
        let buildsAlphaSections: Bool
    }

    nonisolated struct LibraryDerivedInputToken: Hashable {
        let sourceSignature: Int
        let input: LibraryDerivedInput
    }

    nonisolated struct LibraryDerivedState: Equatable {
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
                    normalizedSearchText: "",
                    selectedStatusRawValue: nil,
                    selectedTag: nil,
                    selectedCollectionName: nil,
                    onlyWithNotes: false,
                    smartFilter: nil,
                    longInactiveCutoff: nil,
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
