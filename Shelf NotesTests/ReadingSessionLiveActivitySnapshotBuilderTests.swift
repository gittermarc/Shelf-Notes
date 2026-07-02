import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSessionLiveActivitySnapshotBuilderTests {
    @Test @MainActor func bookWithPagesAndProgressBuildsReadingSnapshot() throws {
        let bookID = UUID(uuidString: "C8FB1D8C-7670-41C8-B941-3180BA93E0D9")!
        let book = Book(title: "Dune", author: "Frank Herbert", status: .reading)
        book.id = bookID
        book.pageCount = 400

        let session = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_900),
            pagesRead: 120,
            note: nil
        )
        book.readingSessionsSafe = [session]

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: book.readingSessionsSafe,
            isPaused: false,
            hasCover: true,
            accentHex: "ff9500"
        )

        #expect(snapshot.bookID == bookID)
        #expect(snapshot.bookTitle == "Dune")
        #expect(snapshot.bookAuthor == "Frank Herbert")
        #expect(snapshot.pageCount == 400)
        #expect(snapshot.pagesRead == 120)
        #expect(snapshot.remainingPages == 280)
        #expect(abs((snapshot.progressFraction ?? 0) - 0.3) < 0.0001)
        #expect(snapshot.stateLabel == ReadingSessionLiveActivitySnapshot.runningStateLabel)
        #expect(snapshot.hasCover)
        #expect(snapshot.coverRevision == 1)
        #expect(snapshot.accentHex == "#FF9500")
    }

    @Test @MainActor func bookWithoutPageCountKeepsPagesButOmitsProgressAndRemainingPages() {
        let book = Book(title: "No Pages", author: "", status: .reading)
        let session = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 2_000),
            endedAt: Date(timeIntervalSince1970: 2_600),
            pagesRead: 18,
            note: nil
        )
        book.readingSessionsSafe = [session]

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: book.readingSessionsSafe,
            isPaused: false,
            hasCover: false
        )

        #expect(snapshot.pageCount == nil)
        #expect(snapshot.pagesRead == 18)
        #expect(snapshot.remainingPages == nil)
        #expect(snapshot.progressFraction == nil)
        #expect(snapshot.bookAuthor == nil)
        #expect(snapshot.hasCover == false)
        #expect(snapshot.coverRevision == nil)
    }

    @Test @MainActor func missingAuthorAndLongTitleAreNormalized() {
        let longTitle = String(repeating: "Sehr langer Titel ", count: 12)
        let book = Book(title: longTitle, author: "   ", status: .reading)

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: [],
            isPaused: false,
            hasCover: false
        )

        #expect(snapshot.bookTitle.count == 80)
        #expect(snapshot.bookAuthor == nil)
    }

    @Test @MainActor func pausedSessionUsesPausedStateLabel() {
        let book = Book(title: "Pausenbuch", author: "Autorin", status: .reading)

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: [],
            isPaused: true,
            hasCover: false
        )

        #expect(snapshot.stateLabel == ReadingSessionLiveActivitySnapshot.pausedStateLabel)
    }

    @Test @MainActor func activeRereadAttemptProvidesAttemptName() {
        let book = Book(title: "Reread", author: "Autor", status: .reading)
        let completed = ReadingAttempt(book: book, sequenceNumber: 1, status: .finished)
        let active = ReadingAttempt(book: book, sequenceNumber: 2, status: .active)
        book.readingAttemptsSafe = [completed, active]

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: [],
            isPaused: false,
            hasCover: false
        )

        #expect(snapshot.attemptName == "2. Durchgang")
    }

    @Test @MainActor func challengeHintIsMappedIntoSnapshot() {
        let book = Book(title: "Challenge Buch", author: "Autor", status: .reading)
        let hint = makeHint(
            title: "Tagesmission",
            detail: "Noch 12 min",
            progressText: "18/30 min",
            remainingText: "Noch 12 min",
            progressFraction: 0.6
        )

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: [],
            challengeHints: [hint],
            isPaused: false,
            hasCover: false
        )

        #expect(snapshot.challengeTitle == "Tagesmission")
        #expect(snapshot.challengeDetail == "Noch 12 min")
        #expect(abs((snapshot.challengeProgressFraction ?? 0) - 0.6) < 0.0001)
    }

    @Test @MainActor func missingChallengeHintLeavesChallengePayloadEmpty() {
        let book = Book(title: "Ohne Challenge", author: "Autor", status: .reading)

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: [],
            challengeHints: [],
            isPaused: false,
            hasCover: false
        )

        #expect(snapshot.challengeTitle == nil)
        #expect(snapshot.challengeDetail == nil)
        #expect(snapshot.challengeProgressFraction == nil)
    }

    @Test @MainActor func zeroPageCountDoesNotProduceInvalidProgress() {
        let book = Book(title: "Zero", author: "Autor", status: .reading)
        book.pageCount = 0
        let session = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 3_000),
            endedAt: Date(timeIntervalSince1970: 3_300),
            pagesRead: 10,
            note: nil
        )
        book.readingSessionsSafe = [session]

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: book.readingSessionsSafe,
            isPaused: false,
            hasCover: false
        )

        #expect(snapshot.pageCount == nil)
        #expect(snapshot.progressFraction == nil)
        #expect(snapshot.remainingPages == nil)
        #expect(snapshot.pagesRead == 10)
    }

    @Test func contentStateCarriesSnapshotValuesForExtensionRendering() {
        let bookID = UUID(uuidString: "557C31FB-D825-43F6-B120-0676F1A0C351")!
        let now = Date(timeIntervalSince1970: 4_000)
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: "State Book",
            pageCount: 300,
            pagesRead: 75,
            remainingPages: 225,
            progressFraction: 0.25,
            challengeTitle: "Wochenziel",
            challengeDetail: "Noch 20 Seiten",
            challengeProgressFraction: 0.7,
            stateLabel: "Liest gerade",
            hasCover: true,
            coverRevision: 3,
            accentHex: "#34c759"
        )
        let blob = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "State Book",
            startedAt: now.addingTimeInterval(-900),
            lastResumedAt: now.addingTimeInterval(-300),
            accumulatedSeconds: 600,
            isPaused: false,
            pausedAt: nil,
            liveActivitySnapshot: snapshot
        )

        let state = ReadingSessionActivityAttributes.ContentState(active: blob, now: now)
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)

        #expect(state.pausedElapsedSeconds == 900)
        #expect(state.pageCount == 300)
        #expect(state.pagesRead == 75)
        #expect(state.remainingPages == 225)
        #expect(abs((state.progressFraction ?? 0) - 0.25) < 0.0001)
        #expect(state.challengeTitle == "Wochenziel")
        #expect(state.challengeDetail == "Noch 20 Seiten")
        #expect(abs((state.challengeProgressFraction ?? 0) - 0.7) < 0.0001)
        #expect(state.hasCover == true)
        #expect(state.coverRevision == 3)
        #expect(state.accentHex == "#34C759")
        #expect(attributes.bookAuthor == nil)
        #expect(attributes.hasCover == true)
    }

    @Test func contentStateUsesCurrentPauseFlagForStatusLabel() {
        let bookID = UUID(uuidString: "B3AF5F93-184A-4C31-A6BF-6DE2D063B3BF")!
        let now = Date(timeIntervalSince1970: 5_000)
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: "Paused Book",
            stateLabel: ReadingSessionLiveActivitySnapshot.runningStateLabel,
            hasCover: false
        )
        let blob = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "Paused Book",
            startedAt: now.addingTimeInterval(-600),
            lastResumedAt: now.addingTimeInterval(-300),
            accumulatedSeconds: 300,
            isPaused: true,
            pausedAt: now.addingTimeInterval(-60),
            liveActivitySnapshot: snapshot
        )

        let state = ReadingSessionActivityAttributes.ContentState(active: blob, now: now)

        #expect(state.stateLabel == ReadingSessionLiveActivitySnapshot.pausedStateLabel)
    }

    @Test @MainActor func snapshotFallbacksKeepSparseBookRenderable() {
        let book = Book(title: "   ", author: "", status: .reading)
        book.pageCount = -10

        let snapshot = ReadingSessionLiveActivitySnapshotBuilder.make(
            book: book,
            allSessions: [],
            isPaused: false,
            hasCover: false,
            accentHex: "not-a-color"
        )

        #expect(snapshot.bookTitle == ReadingSessionLiveActivitySnapshot.defaultTitle)
        #expect(snapshot.bookAuthor == nil)
        #expect(snapshot.pageCount == nil)
        #expect(snapshot.pagesRead == nil)
        #expect(snapshot.remainingPages == nil)
        #expect(snapshot.progressFraction == nil)
        #expect(snapshot.accentHex == nil)
    }

    private func makeHint(
        title: String,
        detail: String,
        progressText: String,
        remainingText: String,
        progressFraction: Double
    ) -> ChallengeActionHint {
        ChallengeActionHint(
            id: UUID(),
            challengeID: UUID(),
            kind: .daily,
            metric: .readingMinutes,
            title: title,
            message: "Message",
            detail: detail,
            progressText: progressText,
            remainingText: remainingText,
            progressFraction: progressFraction,
            systemImage: "clock",
            priority: 0
        )
    }
}
