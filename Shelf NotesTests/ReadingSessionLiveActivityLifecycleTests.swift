import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSessionLiveActivityLifecycleTests {
    @Test func staleDateUsesAutoStopWindowForRunningSessions() {
        let now = Date(timeIntervalSince1970: 10_000)

        let stale = ReadingSessionLiveActivityLifecyclePolicy.staleDate(
            now: now,
            isPaused: false,
            autoStopMinutes: 45
        )

        #expect(stale == now.addingTimeInterval(TimeInterval(45 * 60 + 5 * 60)))
    }

    @Test func staleDateUsesPausedWindowForPausedSessions() {
        let now = Date(timeIntervalSince1970: 20_000)

        let stale = ReadingSessionLiveActivityLifecyclePolicy.staleDate(
            now: now,
            isPaused: true,
            autoStopMinutes: 45
        )

        #expect(stale == now.addingTimeInterval(TimeInterval(12 * 60 * 60)))
    }

    @Test func staleDateFallsBackWhenAutoStopIsUnavailable() {
        let now = Date(timeIntervalSince1970: 30_000)

        let stale = ReadingSessionLiveActivityLifecyclePolicy.staleDate(
            now: now,
            isPaused: false,
            autoStopMinutes: nil
        )

        #expect(stale == now.addingTimeInterval(TimeInterval(8 * 60 * 60)))
    }

    @Test func deepLinkBuildsAndParsesSessionRoute() throws {
        let bookID = UUID(uuidString: "DAB77D1B-8899-4E51-A0B5-1D60C3F27E21")!
        let url = try #require(ReadingSessionLiveActivityDeepLink.url(bookID: bookID))

        let route = try #require(ReadingSessionLiveActivityDeepLink.route(from: url))

        #expect(route.bookID == bookID)
        #expect(route.destination == .session)
    }

    @Test func deepLinkBuildsAndParsesCompletionRoute() throws {
        let bookID = UUID(uuidString: "84C8C2E9-E29E-4900-AC0F-40E4B206D369")!
        let url = try #require(ReadingSessionLiveActivityDeepLink.url(bookID: bookID, destination: .completion))

        let route = try #require(ReadingSessionLiveActivityDeepLink.route(from: url))

        #expect(route.bookID == bookID)
        #expect(route.destination == .completion)
    }

    @Test func deepLinkRejectsUnknownSchemeOrMissingBookID() {
        #expect(ReadingSessionLiveActivityDeepLink.route(from: URL(string: "other://reading-session?bookID=84C8C2E9-E29E-4900-AC0F-40E4B206D369")!) == nil)
        #expect(ReadingSessionLiveActivityDeepLink.route(from: URL(string: "shelfnotes://reading-session")!) == nil)
    }

    @Test func activeBlobRoundTripsWithCurrentSchemaVersion() throws {
        let now = Date(timeIntervalSince1970: 40_000)
        let bookID = UUID(uuidString: "FE931DA6-53E0-4B9D-80C0-66080767F379")!
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: "Lifecycle",
            pageCount: 240,
            pagesRead: 60,
            remainingPages: 180,
            progressFraction: 0.25,
            hasCover: true
        )
        let blob = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "Lifecycle",
            startedAt: now.addingTimeInterval(-600),
            lastResumedAt: now.addingTimeInterval(-120),
            accumulatedSeconds: 480,
            isPaused: false,
            pausedAt: nil,
            liveActivitySnapshot: snapshot
        )

        let data = try #require(ReadingTimerSharedCodec.encodeActive(blob))
        let decoded = try #require(ReadingTimerSharedCodec.decodeActive(from: data))

        #expect(decoded.schemaVersion == ReadingTimerActiveBlob.currentSchemaVersion)
        #expect(decoded.hasSupportedSchemaVersion)
        #expect(decoded.totalElapsedSeconds(now: now) == 600)
        #expect(decoded.liveActivitySnapshot == snapshot)
    }

    @Test func activeBlobDecodesLegacyPayloadWithoutSchemaVersion() throws {
        let now = Date(timeIntervalSince1970: 50_000)
        let bookID = UUID(uuidString: "67284454-4BA5-426E-8C5A-3FF66E929962")!
        let legacy = LegacyActiveBlob(
            bookID: bookID,
            bookTitle: "Legacy",
            startedAt: now.addingTimeInterval(-300),
            lastResumedAt: now.addingTimeInterval(-120),
            accumulatedSeconds: 180,
            isPaused: true,
            pausedAt: nil
        )
        let data = try JSONEncoder().encode(legacy)

        let decoded = try #require(ReadingTimerSharedCodec.decodeActive(from: data))

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.hasSupportedSchemaVersion)
        #expect(decoded.bookTitle == "Legacy")
        #expect(decoded.isPaused)
        #expect(decoded.pausedAt != nil)
        #expect(decoded.totalElapsedSeconds(now: now) == 180)
    }

    @Test func activeBlobFlagsFutureSchemaAsUnsupported() {
        let blob = ReadingTimerActiveBlob(
            schemaVersion: ReadingTimerActiveBlob.currentSchemaVersion + 1,
            bookID: UUID(),
            bookTitle: "Future",
            startedAt: Date(timeIntervalSince1970: 60_000),
            lastResumedAt: Date(timeIntervalSince1970: 60_000),
            accumulatedSeconds: 0,
            isPaused: false,
            pausedAt: nil
        )

        #expect(!blob.hasSupportedSchemaVersion)
    }

    @Test func corruptedSharedStateDecodesAsNil() {
        let data = Data("not-json".utf8)

        #expect(ReadingTimerSharedCodec.decodeActive(from: data) == nil)
        #expect(ReadingTimerSharedCodec.decodePendingCompletion(from: data) == nil)
    }

    @Test func pauseAndResumeMutateSharedBlobDeterministically() {
        let start = Date(timeIntervalSince1970: 70_000)
        let pauseTime = start.addingTimeInterval(90)
        let resumeTime = pauseTime.addingTimeInterval(30)
        let bookID = UUID(uuidString: "AF91D3DC-311F-4C01-813F-E9BDE6E13823")!
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: "Toggle",
            hasCover: false
        )
        var blob = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "Toggle",
            startedAt: start,
            lastResumedAt: start,
            accumulatedSeconds: 0,
            isPaused: false,
            pausedAt: nil,
            liveActivitySnapshot: snapshot
        )

        blob.pause(now: pauseTime)

        #expect(blob.isPaused)
        #expect(blob.accumulatedSeconds == 90)
        #expect(blob.pausedAt == pauseTime)
        #expect(blob.liveActivitySnapshot?.stateLabel == ReadingSessionLiveActivitySnapshot.pausedStateLabel)

        blob.resume(now: resumeTime)

        #expect(!blob.isPaused)
        #expect(blob.pausedAt == nil)
        #expect(blob.lastResumedAt == resumeTime)
        #expect(blob.liveActivitySnapshot?.stateLabel == ReadingSessionLiveActivitySnapshot.runningStateLabel)
    }

    @Test func pendingCompletionRoundTripsAndNormalizesDuration() throws {
        let now = Date(timeIntervalSince1970: 80_000)
        let pending = ReadingTimerPendingCompletionBlob(
            id: UUID(uuidString: "51027857-8B17-4EE4-AB18-11F50EE4733B")!,
            bookID: UUID(uuidString: "0D5E2B5F-D634-49E7-A2F4-5E50F809F853")!,
            bookTitle: "Pending",
            startedAt: now.addingTimeInterval(-120),
            endedAt: now,
            durationSeconds: -50,
            wasAutoStopped: false,
            autoStopMinutes: nil
        )

        let data = try #require(ReadingTimerSharedCodec.encodePendingCompletion(pending))
        let decoded = try #require(ReadingTimerSharedCodec.decodePendingCompletion(from: data))

        #expect(decoded.schemaVersion == ReadingTimerPendingCompletionBlob.currentSchemaVersion)
        #expect(decoded.hasSupportedSchemaVersion)
        #expect(decoded.durationSeconds == 0)
        #expect(decoded.bookTitle == "Pending")
    }

    @Test func coverCleanupOnlyRemovesLiveActivityCoverFilesWithoutKeepers() {
        let keptID = UUID(uuidString: "8F3994C4-B40A-4137-BC60-11F47C8EC740")!.uuidString
        let removedID = UUID(uuidString: "C82BF512-CB24-4D9B-8835-25D8D2CF4088")!.uuidString
        let existing = [
            LiveActivitySharedStore.coverFileName(bookIDString: keptID),
            LiveActivitySharedStore.coverFileName(bookIDString: removedID),
            "notes.txt",
            "la_cover_not-a-uuid.jpg"
        ]

        let removable = LiveActivityCoverCleanupPolicy.fileNamesToRemove(
            existingFileNames: existing,
            keepingBookIDStrings: [keptID]
        )

        #expect(removable == [LiveActivitySharedStore.coverFileName(bookIDString: removedID)])
    }

    private struct LegacyActiveBlob: Encodable {
        let bookID: UUID
        let bookTitle: String
        let startedAt: Date
        let lastResumedAt: Date
        let accumulatedSeconds: Int
        let isPaused: Bool
        let pausedAt: Date?
    }
}
