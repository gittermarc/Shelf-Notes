import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSessionMutationServiceTests {

    @Test @MainActor func timerSessionWithPagesReachesBookCompletion() throws {
        let book = Book(title: "Almost Done", status: .reading)
        book.pageCount = 100
        let existing = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_200),
            pagesRead: 70,
            note: nil
        )
        book.readingSessionsSafe = [existing]

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 2_000),
            endedAt: Date(timeIntervalSince1970: 2_900)
        )
        let result = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: book.readingSessionsSafe,
            timing: timing,
            pages: 30,
            note: "  Finale geschafft  "
        )

        let mutationPlan = try result.get()

        #expect(mutationPlan.plan.didMarkFinished)
        #expect(mutationPlan.plan.updatedBookState.status == .finished)
        #expect(mutationPlan.plan.updatedBookState.readFrom == existing.startedAt)
        #expect(mutationPlan.plan.updatedBookState.readTo == timing.endedAt)
        #expect(mutationPlan.plan.normalizedPages == 30)
        #expect(mutationPlan.plan.trimmedNote == "Finale geschafft")
    }

    @Test @MainActor func invalidPagesReturnValidationFailureWithoutSaveSuccess() {
        let book = Book(title: "Too Much", status: .reading)
        book.pageCount = 120
        let existing = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 3_000),
            endedAt: Date(timeIntervalSince1970: 3_300),
            pagesRead: 100,
            note: nil
        )
        book.readingSessionsSafe = [existing]

        let result = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: book.readingSessionsSafe,
            timing: ReadingSessionLogging.Timing(
                startedAt: Date(timeIntervalSince1970: 4_000),
                endedAt: Date(timeIntervalSince1970: 4_600)
            ),
            pages: 25,
            note: nil
        )

        guard case .failure(.pagesExceedRemaining(let remaining, let total)) = result else {
            #expect(Bool(false))
            return
        }

        #expect(remaining == 20)
        #expect(total == 120)
    }

    @Test @MainActor func legacySupplementForFinishedBookStaysPossible() throws {
        let firstStart = Date(timeIntervalSince1970: 5_000)
        let firstFinish = Date(timeIntervalSince1970: 6_000)
        let book = Book(title: "Finished Supplement", status: .finished)
        book.pageCount = 240
        book.readFrom = firstStart
        book.readTo = firstFinish

        let result = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: book.readingSessionsSafe,
            timing: ReadingSessionLogging.Timing(
                startedAt: Date(timeIntervalSince1970: 7_000),
                endedAt: Date(timeIntervalSince1970: 7_900)
            ),
            pages: 12,
            note: "  Bookclub-Nachtrag  "
        )

        let mutationPlan = try result.get()

        #expect(mutationPlan.allowsFinishedBookSupplement)
        #expect(mutationPlan.activeAttempt == nil)
        #expect(mutationPlan.plan.isLegacySupplement)
        #expect(mutationPlan.plan.didMarkFinished == false)
        #expect(mutationPlan.plan.updatedBookState.status == .finished)
        #expect(mutationPlan.plan.updatedBookState.readFrom == firstStart)
        #expect(mutationPlan.plan.updatedBookState.readTo == firstFinish)
        #expect(mutationPlan.plan.trimmedNote == "Bookclub-Nachtrag")
    }

    @Test @MainActor func activeRereadPlanUsesOnlyActiveAttemptSessions() throws {
        let book = Book(title: "Reread", status: .reading)
        book.pageCount = 100
        let completed = ReadingAttempt(book: book, sequenceNumber: 1, status: .finished)
        let active = ReadingAttempt(book: book, sequenceNumber: 2, status: .active)
        book.readingAttemptsSafe = [completed, active]

        let completedSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 8_000),
            endedAt: Date(timeIntervalSince1970: 8_300),
            pagesRead: 100,
            note: nil
        )
        completedSession.readingAttempt = completed
        completed.addSessionIfNeeded(completedSession)

        let activeSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 9_000),
            endedAt: Date(timeIntervalSince1970: 9_300),
            pagesRead: 20,
            note: nil
        )
        activeSession.readingAttempt = active
        active.addSessionIfNeeded(activeSession)
        book.readingSessionsSafe = [completedSession, activeSession]

        let result = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: book.readingSessionsSafe,
            timing: ReadingSessionLogging.Timing(
                startedAt: Date(timeIntervalSince1970: 10_000),
                endedAt: Date(timeIntervalSince1970: 10_900)
            ),
            pages: 80,
            note: nil
        )

        let mutationPlan = try result.get()

        #expect(mutationPlan.activeAttempt?.id == active.id)
        #expect(mutationPlan.scopedSessions.map(\.id) == [activeSession.id])
        #expect(mutationPlan.plan.didMarkFinished)
        #expect(mutationPlan.plan.normalizedPages == 80)
    }

    @Test @MainActor func savedSessionSnapshotNormalizesPagesAndNote() {
        let bookID = UUID(uuidString: "5B271F82-A025-4EBD-A379-C00B56530E48")!
        let sessionID = UUID(uuidString: "D79E8E51-F04B-494B-A064-7421D054D0F7")!
        let snapshot = SavedReadingSessionSnapshot(
            id: sessionID,
            bookID: bookID,
            startedAt: Date(timeIntervalSince1970: 11_000),
            endedAt: Date(timeIntervalSince1970: 11_600),
            durationSeconds: 600,
            pagesRead: -4,
            note: "  Gute Session  "
        )

        #expect(snapshot.id == sessionID)
        #expect(snapshot.bookID == bookID)
        #expect(snapshot.durationSeconds == 600)
        #expect(snapshot.pagesRead == nil)
        #expect(snapshot.note == "Gute Session")
        #expect(snapshot.hasNote)
    }
}
