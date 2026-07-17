import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingSessionAttemptIsolationTests {

    @Test @MainActor func activeRereadIgnoresCompletedAttemptProgress() throws {
        let book = Book(title: "Reread", status: .reading)
        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        let oldEvent = ReadingProgressEvent(
            book: book,
            readingAttempt: completed,
            occurredAt: Date(timeIntervalSince1970: 2_600),
            progressUnit: .percentage,
            nativeValue: 100,
            totalValue: 100,
            normalizedProgress: 1,
            deduplicationKey: "old"
        )
        let activeEvent = ReadingProgressEvent(
            book: book,
            readingAttempt: active,
            occurredAt: Date(timeIntervalSince1970: 2_700),
            progressUnit: .percentage,
            nativeValue: 20,
            totalValue: 100,
            normalizedProgress: 0.2,
            deduplicationKey: "active"
        )
        book.readingAttemptsSafe = [completed, active]
        book.readingProgressEventsSafe = [oldEvent, activeEvent]
        completed.progressEventsSafe = [oldEvent]
        active.progressEventsSafe = [activeEvent]
        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 2_800),
            endedAt: Date(timeIntervalSince1970: 2_900)
        )

        let plan = try ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: [],
            timing: timing,
            progressUpdate: .percentage(
                normalizedProgress: 0.3,
                occurredAt: timing.endedAt
            ),
            note: nil,
            source: ReadingSessionSource(
                medium: .ebook,
                provider: .other,
                progressUnit: .percentage,
                origin: .quickLog,
                totalValue: 100
            )
        ).get()

        #expect(plan.activeAttempt?.id == active.id)
        #expect(plan.currentProgress.normalizedProgress == 0.2)
        #expect(plan.plan.progress.startNormalizedProgress == 0.2)
        #expect(plan.plan.progress.endNormalizedProgress == 0.3)
    }

    @Test @MainActor func finishedLegacyBookStillAcceptsSupplementSession() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let firstStart = Date(timeIntervalSince1970: 3_000)
        let firstEnd = Date(timeIntervalSince1970: 3_100)
        let book = Book(title: "Supplement", status: .finished)
        book.pageCount = 100
        book.readFrom = firstStart
        book.readTo = firstEnd
        context.insert(book)

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 3_200),
            endedAt: Date(timeIntervalSince1970: 3_300)
        )
        let mutation = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            pages: 5,
            note: "Bookclub",
            allSessions: [],
            now: timing.endedAt
        ).get()

        #expect(mutation.isLegacySupplement)
        #expect(mutation.session.readingAttempt == nil)
        #expect(book.status == .finished)
        #expect(book.readFrom == firstStart)
        #expect(book.readTo == firstEnd)
        #expect(mutation.progressEvent?.sourceSessionID == mutation.session.id)
    }
}
