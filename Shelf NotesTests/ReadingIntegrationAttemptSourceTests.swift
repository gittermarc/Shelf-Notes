import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingIntegrationAttemptSourceTests {
    @Test @MainActor func activeAttemptSourceCanChangeBeforeSessionsOrProgress() {
        let book = Book(title: "Switch", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            status: .active,
            readingMedium: .ebook,
            defaultProvider: .appleBooks,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        let attemptID = attempt.id
        book.readingAttemptsSafe = [attempt]

        #expect(ReadingSourceAttemptMutation.canChangeSource(of: attempt))

        ReadingSourceAttemptMutation.apply(
            ReadingSourceDraft(selection: .kindle),
            to: attempt,
            book: book,
            now: Date(timeIntervalSince1970: 250_000)
        )

        #expect(attempt.id == attemptID)
        #expect(book.activeReadingAttempt?.id == attemptID)
        #expect(attempt.readingMedium == .ebook)
        #expect(attempt.defaultProvider == .kindle)
        #expect(attempt.progressUnit == .percentage)
        #expect(attempt.totalValueSnapshot == 100)
    }

    @Test @MainActor func activeAttemptSourceIsLockedAfterSessionOrProgress() {
        let book = Book(title: "Locked", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            status: .active,
            readingMedium: .ebook,
            defaultProvider: .kindle,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        let session = ReadingSession(
            book: book,
            startAt: Date(timeIntervalSince1970: 260_000),
            durationSeconds: 600,
            pagesRead: 0
        )
        attempt.sessionsSafe = [session]
        book.readingAttemptsSafe = [attempt]
        book.readingSessions = [session]

        #expect(!ReadingSourceAttemptMutation.canChangeSource(of: attempt))

        attempt.sessionsSafe = []
        let event = ReadingProgressEvent(
            book: book,
            readingAttempt: attempt,
            occurredAt: Date(timeIntervalSince1970: 260_600),
            medium: .ebook,
            provider: .kindle,
            progressUnit: .percentage,
            nativeValue: 30,
            totalValue: 100,
            normalizedProgress: 0.3,
            origin: .quickLog,
            deduplicationKey: "lock-progress"
        )
        attempt.progressEventsSafe = [event]
        book.readingProgressEventsSafe = [event]

        #expect(!ReadingSourceAttemptMutation.canChangeSource(of: attempt))
    }
}