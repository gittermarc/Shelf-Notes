import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingProgressRepairTests {

    @Test @MainActor func repairClassifiesMissingSourcesAndRestoresRelationships() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let book = Book(title: "Repair", status: .reading)
        let attempt = ReadingAttempt(sequenceNumber: 1, status: .active)
        attempt.readingMediumRawValue = " "
        attempt.defaultProviderRawValue = ""
        attempt.progressUnitRawValue = "\n"

        let session = ReadingSession(
            startedAt: now,
            endedAt: now.addingTimeInterval(60),
            pagesRead: nil
        )
        session.mediumRawValue = ""
        session.providerRawValue = " "
        session.progressUnitRawValue = ""
        session.originRawValue = "\n"

        let event = ReadingProgressEvent(
            occurredAt: now,
            nativeValue: 0,
            deduplicationKey: "source-session",
            sourceSessionID: session.id
        )
        event.mediumRawValue = ""
        event.providerRawValue = " "
        event.progressUnitRawValue = ""
        event.originRawValue = "\n"

        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [session]
        book.readingProgressEventsSafe = [event]

        let firstRun = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: [event],
            now: now
        )
        let secondRun = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: book.readingProgressEventsSafe,
            now: now
        )

        #expect(firstRun)
        #expect(secondRun == false)
        #expect(attempt.book?.id == book.id)
        #expect(attempt.readingMedium == .physical)
        #expect(attempt.defaultProvider == .none)
        #expect(attempt.progressUnit == .pages)
        #expect(session.book?.id == book.id)
        #expect(session.readingAttempt?.id == attempt.id)
        #expect(session.medium == .physical)
        #expect(session.provider == .none)
        #expect(session.progressUnit == .pages)
        #expect(session.origin == .legacy)
        #expect(event.book?.id == book.id)
        #expect(event.readingAttempt?.id == attempt.id)
        #expect(event.progressUnit == .none)
        #expect(attempt.progressEventsSafe.map(\.id) == [event.id])
    }

    @Test @MainActor func legacyBaselineIsUpdatedWithoutDuplication() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let book = Book(title: "Baseline", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .active,
            pageCountSnapshot: 100
        )
        let session = ReadingSession(
            book: book,
            startedAt: now,
            endedAt: now.addingTimeInterval(60),
            pagesRead: 10
        )
        session.readingAttempt = attempt
        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [session]
        attempt.sessionsSafe = [session]

        var inserted: [ReadingProgressEvent] = []
        let firstRun = ReadingProgressRepair.repair(
            books: [book],
            now: now,
            insertEvent: { inserted.append($0) }
        )
        let baseline = try #require(book.readingProgressEventsSafe.first)
        let originalID = baseline.id

        session.pagesRead = 25
        let secondRun = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: book.readingProgressEventsSafe,
            now: now.addingTimeInterval(10)
        )
        let thirdRun = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: book.readingProgressEventsSafe,
            now: now.addingTimeInterval(20)
        )

        #expect(firstRun)
        #expect(secondRun)
        #expect(thirdRun == false)
        #expect(inserted.count == 1)
        #expect(book.readingProgressEventsSafe.count == 1)
        #expect(book.readingProgressEventsSafe.first?.id == originalID)
        #expect(book.readingProgressEventsSafe.first?.nativeValue == 25)
        #expect(book.readingProgressEventsSafe.first?.normalizedProgress == 0.25)
        #expect(
            book.readingProgressEventsSafe.first?.deduplicationKey
                == ReadingProgressEventFingerprint.legacyBaselineKey(attemptID: attempt.id)
        )
    }

    @Test @MainActor func laterLegacySessionsUpdateTheExistingBaseline() throws {
        let firstDate = Date(timeIntervalSince1970: 3_000)
        let secondDate = Date(timeIntervalSince1970: 4_000)
        let book = Book(title: "CloudKit Late Arrival", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .active,
            pageCountSnapshot: 200
        )
        let firstSession = makeSession(
            book: book,
            attempt: attempt,
            startedAt: firstDate,
            pagesRead: 20
        )
        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [firstSession]
        attempt.sessionsSafe = [firstSession]

        _ = ReadingProgressRepair.repair(books: [book], now: firstDate)
        let originalID = try #require(book.readingProgressEventsSafe.first?.id)

        let lateSession = makeSession(
            book: book,
            attempt: attempt,
            startedAt: secondDate,
            pagesRead: 30
        )
        book.readingSessionsSafe.append(lateSession)
        attempt.sessionsSafe.append(lateSession)

        let didChange = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: book.readingProgressEventsSafe,
            now: secondDate
        )

        #expect(didChange)
        #expect(book.readingProgressEventsSafe.count == 1)
        #expect(book.readingProgressEventsSafe.first?.id == originalID)
        #expect(book.readingProgressEventsSafe.first?.nativeValue == 50)
        #expect(book.readingProgressEventsSafe.first?.normalizedProgress == 0.25)
        #expect(book.readingProgressEventsSafe.first?.occurredAt == lateSession.endedAt)
    }

    @Test @MainActor func exactDuplicatesAreRemovedButDifferentEventsRemain() {
        let timestamp = Date(timeIntervalSince1970: 5_000)
        let book = Book(title: "Dedupe", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .active,
            progressUnit: .percentage
        )
        let first = makePercentageEvent(
            book: book,
            attempt: attempt,
            timestamp: timestamp,
            value: 25,
            createdAt: timestamp
        )
        let duplicate = makePercentageEvent(
            book: book,
            attempt: attempt,
            timestamp: timestamp,
            value: 25,
            createdAt: timestamp.addingTimeInterval(1)
        )
        let distinct = makePercentageEvent(
            book: book,
            attempt: attempt,
            timestamp: timestamp,
            value: 30,
            createdAt: timestamp.addingTimeInterval(2)
        )
        book.readingAttemptsSafe = [attempt]
        book.readingProgressEventsSafe = [first, duplicate, distinct]
        attempt.progressEventsSafe = [first, duplicate, distinct]
        var deletedIDs = Set<UUID>()

        let didChange = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: [first, duplicate, distinct],
            now: timestamp,
            deleteEvent: { deletedIDs.insert($0.id) }
        )

        #expect(didChange)
        #expect(book.readingProgressEventsSafe.count == 2)
        #expect(book.readingProgressEventsSafe.contains { $0.nativeValue == 25 })
        #expect(book.readingProgressEventsSafe.contains { $0.nativeValue == 30 })
        #expect(deletedIDs == Set([duplicate.id]))
    }

    @Test @MainActor func duplicateLegacyBaselinesCollapseToOneUpdatedEvent() throws {
        let timestamp = Date(timeIntervalSince1970: 5_500)
        let book = Book(title: "Baseline Dedupe", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .active,
            pageCountSnapshot: 100
        )
        let session = makeSession(
            book: book,
            attempt: attempt,
            startedAt: timestamp,
            pagesRead: 35
        )
        let key = ReadingProgressEventFingerprint.legacyBaselineKey(
            attemptID: attempt.id
        )
        let first = ReadingProgressEvent(
            book: book,
            readingAttempt: attempt,
            occurredAt: timestamp,
            progressUnit: .pages,
            nativeValue: 10,
            deduplicationKey: key,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let duplicate = ReadingProgressEvent(
            book: book,
            readingAttempt: attempt,
            occurredAt: timestamp,
            progressUnit: .pages,
            nativeValue: 20,
            deduplicationKey: key,
            createdAt: timestamp.addingTimeInterval(1),
            updatedAt: timestamp.addingTimeInterval(1)
        )
        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [session]
        book.readingProgressEventsSafe = [first, duplicate]
        attempt.sessionsSafe = [session]
        attempt.progressEventsSafe = [first, duplicate]
        var deletedIDs = Set<UUID>()

        let didChange = ReadingProgressRepair.repair(
            books: [book],
            knownEvents: [first, duplicate],
            now: timestamp.addingTimeInterval(2),
            deleteEvent: { deletedIDs.insert($0.id) }
        )
        let canonical = try #require(book.readingProgressEventsSafe.first)

        #expect(didChange)
        #expect(book.readingProgressEventsSafe.count == 1)
        #expect(attempt.progressEventsSafe.count == 1)
        #expect(canonical.id == first.id)
        #expect(canonical.nativeValue == 35)
        #expect(canonical.totalValue == 100)
        #expect(canonical.normalizedProgress == 0.35)
        #expect(deletedIDs == Set([duplicate.id]))
    }

    @Test @MainActor func inMemoryRepairRemainsIdempotent() async throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let timestamp = Date(timeIntervalSince1970: 6_000)
        let book = Book(title: "Stored Repair", status: .reading)
        book.pageCount = 160
        let session = ReadingSession(
            book: book,
            startedAt: timestamp,
            endedAt: timestamp.addingTimeInterval(60),
            pagesRead: 40
        )
        context.insert(book)
        context.insert(session)
        book.readingSessionsSafe = [session]
        try context.save()

        await ReadingAttemptRepair.repairIfNeeded(modelContext: context)
        await ReadingProgressRepair.repairIfNeeded(modelContext: context)
        await ReadingProgressRepair.repairIfNeeded(modelContext: context)

        let attempts = try context.fetch(FetchDescriptor<ReadingAttempt>())
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(attempts.count == 1)
        #expect(events.count == 1)
        #expect(events.first?.nativeValue == 40)
        #expect(events.first?.readingAttempt?.id == attempts.first?.id)
    }

    @MainActor
    private func makeSession(
        book: Book,
        attempt: ReadingAttempt,
        startedAt: Date,
        pagesRead: Int
    ) -> ReadingSession {
        let session = ReadingSession(
            book: book,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(60),
            pagesRead: pagesRead
        )
        session.readingAttempt = attempt
        return session
    }

    @MainActor
    private func makePercentageEvent(
        book: Book,
        attempt: ReadingAttempt,
        timestamp: Date,
        value: Double,
        createdAt: Date
    ) -> ReadingProgressEvent {
        ReadingProgressEvent(
            book: book,
            readingAttempt: attempt,
            occurredAt: timestamp,
            medium: .ebook,
            provider: .other,
            progressUnit: .percentage,
            nativeValue: value,
            totalValue: 100,
            normalizedProgress: value / 100,
            origin: .providerImport,
            externalIdentifier: "event-\(Int(value))",
            deduplicationKey: "provider:batch",
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}