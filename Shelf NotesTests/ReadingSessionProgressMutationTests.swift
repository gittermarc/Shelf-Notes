import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingSessionProgressMutationTests {

    @Test @MainActor func pageSessionCreatesLinkedEventAndCompletesAtomically() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Pages", status: .reading)
        book.pageCount = 100
        let existing = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            pagesRead: 70
        )
        context.insert(book)
        context.insert(existing)
        book.readingSessionsSafe = [existing]
        try context.save()

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 300),
            endedAt: Date(timeIntervalSince1970: 400)
        )
        let result = ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            pages: 30,
            note: "Done",
            allSessions: book.readingSessionsSafe,
            now: timing.endedAt,
            origin: .quickLog
        )
        let mutation = try result.get()
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(mutation.didMarkBookFinished)
        #expect(book.status == .finished)
        #expect(book.activeReadingAttempt == nil)
        #expect(mutation.session.pagesRead == 30)
        #expect(mutation.session.origin == .quickLog)
        #expect(events.count == 1)
        #expect(events.first?.sourceSessionID == mutation.session.id)
        #expect(events.first?.nativeValue == 100)
        #expect(events.first?.normalizedProgress == 1)
        #expect(mutation.sessionSnapshot.progressEventID == events.first?.id)
    }

    @Test @MainActor func percentageSessionStoresAbsoluteProgressWithoutPages() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Percentage", status: .toRead)
        context.insert(book)

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 600)
        )
        let update = ReadingProgressUpdate.percentage(
            nativeValue: 45,
            totalValue: 100,
            occurredAt: timing.endedAt
        )
        let source = ReadingSessionSource(
            medium: .ebook,
            provider: .other,
            progressUnit: .percentage,
            origin: .integratedReader,
            totalValue: 100
        )
        let mutation = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            progressUpdate: update,
            note: nil,
            source: source,
            allSessions: [],
            now: timing.endedAt
        ).get()

        #expect(book.status == .reading)
        #expect(mutation.session.pagesRead == nil)
        #expect(mutation.session.medium == .ebook)
        #expect(mutation.session.progressUnit == .percentage)
        #expect(mutation.session.endValue == 45)
        #expect(mutation.session.endNormalizedProgress == 0.45)
        #expect(mutation.progressEvent?.nativeValue == 45)
        #expect(mutation.progressEvent?.normalizedProgress == 0.45)
        #expect(mutation.progressEvent?.sourceSessionID == mutation.session.id)
    }

    @Test @MainActor func locatorSessionWithoutNormalizedValueDoesNotInventProgress() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Locator", status: .reading)
        context.insert(book)

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 700),
            endedAt: Date(timeIntervalSince1970: 800)
        )
        let mutation = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            progressUpdate: .locator(
                "epubcfi(/6/4!/4/2)",
                occurredAt: timing.endedAt
            ),
            note: "Marker",
            source: ReadingSessionSource(
                medium: .ebook,
                provider: .localFile,
                progressUnit: .locator,
                origin: .integratedReader
            ),
            allSessions: [],
            now: timing.endedAt
        ).get()

        #expect(mutation.session.endLocator == "epubcfi(/6/4!/4/2)")
        #expect(mutation.session.endNormalizedProgress == nil)
        #expect(mutation.progressEvent?.locator == "epubcfi(/6/4!/4/2)")
        #expect(mutation.progressEvent?.normalizedProgress == nil)
    }

    @Test @MainActor func sessionWithoutProgressStoresTimeAndNoteWithoutEvent() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Time Only", status: .toRead)
        context.insert(book)

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 900),
            endedAt: Date(timeIntervalSince1970: 1_500)
        )
        let mutation = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            progressUpdate: nil,
            note: "Nur gelesen",
            source: ReadingSessionSource(origin: .quickLog),
            allSessions: [],
            now: timing.endedAt
        ).get()
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(book.status == .reading)
        #expect(mutation.session.durationSeconds == 600)
        #expect(mutation.session.pagesRead == nil)
        #expect(mutation.session.note == "Nur gelesen")
        #expect(mutation.progressEvent == nil)
        #expect(events.isEmpty)
    }

    @Test @MainActor func correctionModeCanPersistLowerAbsolutePercentage() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Correction", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        let previous = ReadingProgressEvent(
            book: book,
            readingAttempt: attempt,
            occurredAt: Date(timeIntervalSince1970: 1_600),
            progressUnit: .percentage,
            nativeValue: 80,
            totalValue: 100,
            normalizedProgress: 0.8,
            deduplicationKey: "previous"
        )
        context.insert(book)
        context.insert(attempt)
        context.insert(previous)
        book.readingAttemptsSafe = [attempt]
        book.readingProgressEventsSafe = [previous]
        attempt.progressEventsSafe = [previous]
        try context.save()

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 1_700),
            endedAt: Date(timeIntervalSince1970: 1_800)
        )
        let standard = ReadingSessionMutationService.makePlan(
            book: book,
            allSessions: [],
            timing: timing,
            progressUpdate: .percentage(
                normalizedProgress: 0.4,
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
        )
        guard case .failure(.progressWouldMoveBackward) = standard else {
            #expect(Bool(false))
            return
        }

        let corrected = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            progressUpdate: .percentage(
                normalizedProgress: 0.4,
                occurredAt: timing.endedAt
            ),
            note: nil,
            source: ReadingSessionSource(
                medium: .ebook,
                provider: .other,
                progressUnit: .percentage,
                origin: .quickLog,
                totalValue: 100
            ),
            mutationMode: .correction,
            allSessions: [],
            now: timing.endedAt
        ).get()

        #expect(corrected.progressEvent?.normalizedProgress == 0.4)
    }

    @Test @MainActor func resavingSessionUpdatesSingleLinkedEvent() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Dedupe", status: .reading)
        context.insert(book)
        let source = ReadingSessionSource(
            medium: .ebook,
            provider: .other,
            progressUnit: .percentage,
            origin: .quickLog,
            totalValue: 100
        )
        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 1_900),
            endedAt: Date(timeIntervalSince1970: 2_000)
        )
        let first = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            progressUpdate: .percentage(
                normalizedProgress: 0.4,
                occurredAt: timing.endedAt
            ),
            note: nil,
            source: source,
            allSessions: [],
            now: timing.endedAt
        ).get()

        let secondTiming = ReadingSessionLogging.Timing(
            startedAt: timing.startedAt,
            endedAt: Date(timeIntervalSince1970: 2_100)
        )
        let second = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: secondTiming,
            progressUpdate: .percentage(
                normalizedProgress: 0.6,
                occurredAt: secondTiming.endedAt
            ),
            note: nil,
            source: source,
            allSessions: [first.session],
            now: secondTiming.endedAt,
            existingSession: first.session
        ).get()
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())

        #expect(sessions.count == 1)
        #expect(events.count == 1)
        #expect(second.session.id == first.session.id)
        #expect(second.progressEvent?.id == first.progressEvent?.id)
        #expect(events.first?.normalizedProgress == 0.6)
        #expect(events.first?.sourceSessionID == first.session.id)
    }

}
