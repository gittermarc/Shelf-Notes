//
//  LibraryWidgetSnapshotInputMapper.swift
//  Shelf Notes
//
//  Maps SwiftData models into stable value records for the widget snapshot builder.
//

import Foundation

@MainActor
enum LibraryWidgetSnapshotInputMapper {
    static func bookRecords(from books: [Book]) -> [LibraryWidgetBookRecord] {
        books.map { book in
            let sessions = book.readingSessionsSafe
            let progressSnapshot = book.currentReadingProgressSnapshot
            let sourceAttempt = book.activeReadingAttempt ?? book.orderedReadingAttempts.last
            let medium = sourceAttempt?.readingMedium ?? .physical
            let provider = sourceAttempt?.defaultProvider ?? .none
            let progressUnit = progressSnapshot.unit
            let lastSessionAt = sessions.compactMap { session -> Date? in
                let contribution = ReadingSessionMetricMapper.contribution(
                    from: ReadingSessionMetricInput(
                        startedAt: session.startedAt,
                        durationSeconds: session.durationSeconds,
                        pagesRead: session.pagesReadNormalized,
                        nativeValue: session.endValue,
                        normalizedProgress: session.endNormalizedProgress,
                        locator: session.endLocator,
                        progressUnitRawValue: session.progressUnitRawValue,
                        originRawValue: session.originRawValue
                    )
                )
                return contribution.sessionCount > 0 ? session.startedAt : nil
            }.max()
            let completions = ReadingCompletionRecordBuilder.records(from: book).map { completion in
                LibraryWidgetCompletionRecord(
                    id: completion.id,
                    bookID: completion.bookID,
                    sequenceNumber: completion.sequenceNumber,
                    finishedAt: completion.finishedAt,
                    pageCount: completion.pageCount,
                    isReread: completion.isReread
                )
            }

            return LibraryWidgetBookRecord(
                id: book.id,
                title: book.title,
                author: book.author,
                statusRawValue: book.statusRawValue,
                createdAt: book.createdAt,
                readFrom: book.readFrom,
                readTo: book.readTo,
                pageCount: progressUnit == .pages
                    ? progressSnapshot.totalValue.flatMap(Self.positiveInt) ?? book.pageCount
                    : nil,
                pagesRead: progressUnit == .pages ? (progressSnapshot.pagesRead ?? 0) : 0,
                progressFraction: progressSnapshot.normalizedProgress,
                progressNativeValue: progressSnapshot.nativeValue,
                progressLocator: progressSnapshot.locator,
                mediumRawValue: medium.rawValue,
                providerRawValue: provider.rawValue,
                progressUnitRawValue: progressUnit.rawValue,
                lastSessionAt: lastSessionAt,
                hasCover: book.userCoverData != nil || book.userCoverFileName != nil || book.thumbnailURL != nil,
                coverRevision: coverRevision(for: book),
                completions: completions
            )
        }
    }

    static func goalRecords(from goals: [ReadingGoal]) -> [LibraryWidgetGoalRecord] {
        goals.map { goal in
            LibraryWidgetGoalRecord(
                year: goal.year,
                targetCount: goal.targetCount,
                updatedAt: goal.updatedAt
            )
        }
    }

    private static func coverRevision(for book: Book) -> Int? {
        if let data = book.userCoverData, !data.isEmpty {
            return data.count
        }

        if let fileName = book.userCoverFileName?.trimmingCharacters(in: .whitespacesAndNewlines), !fileName.isEmpty {
            return stablePositiveHash(for: fileName)
        }

        if let thumbnailURL = book.thumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines), !thumbnailURL.isEmpty {
            return stablePositiveHash(for: thumbnailURL)
        }

        return nil
    }

    private static func positiveInt(_ value: Double) -> Int? {
        guard value.isFinite,
              value > 0,
              value.rounded(.towardZero) == value,
              value <= Double(Int.max) else {
            return nil
        }
        return Int(value)
    }

    private static func stablePositiveHash(for value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        let bounded = hash % UInt64(Int.max)
        return max(1, Int(bounded))
    }
}
