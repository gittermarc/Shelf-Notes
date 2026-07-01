import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeRefreshBatchTests {
    @Test func multipleSaveRequestsBecomeOneBatchWithTwoSavedPayloads() {
        let first = makeSessionSnapshot(index: 1, bookIndex: 1)
        let second = makeSessionSnapshot(index: 2, bookIndex: 2)
        let batch = ChallengeRefreshBatch(requests: [
            .readingSessionSaved(sessionSnapshot: first, didMarkBookFinished: false),
            .readingSessionSaved(sessionSnapshot: second, didMarkBookFinished: true)
        ])

        #expect(batch.requests.count == 2)
        #expect(batch.savedSessionPayloads.count == 2)
        #expect(batch.postsReadingSessionChange)
        #expect(batch.readingSessionChangeNotificationCount == 1)
        #expect(batch.savedSessionPayloads.map(\.bookID) == [first.bookID, second.bookID])
    }

    @Test func savePlusDeleteStyleMutationKeepsOneSessionChangeNotification() {
        let snapshot = makeSessionSnapshot(index: 3, bookIndex: 1)
        let deletedSnapshot = makeSessionSnapshot(index: 7, bookIndex: 1)
        let batch = ChallengeRefreshBatch(requests: [
            .readingSessionSaved(sessionSnapshot: snapshot, didMarkBookFinished: false),
            .readingSessionDeleted(sessionSnapshot: deletedSnapshot)
        ])

        #expect(batch.requests.count == 2)
        #expect(batch.savedSessionPayloads.count == 1)
        #expect(batch.mutationPayloads.map(\.kind) == [.saved, .deleted])
        #expect(batch.requiresChallengePreparation)
        #expect(batch.readingSessionChangeNotificationCount == 1)
    }

    @Test func multipleImpactsForDifferentBooksRemainDistinguishable() {
        let first = makeSessionSnapshot(index: 4, bookIndex: 10)
        let second = makeSessionSnapshot(index: 5, bookIndex: 11)
        let batch = ChallengeRefreshBatch(requests: [
            .readingSessionSaved(sessionSnapshot: first, didMarkBookFinished: true),
            .readingSessionSaved(sessionSnapshot: second, didMarkBookFinished: false)
        ])

        let bookIDs = batch.savedSessionPayloads.compactMap(\.bookID)
        #expect(bookIDs.count == 2)
        #expect(Set(bookIDs).count == 2)
        #expect(batch.savedSessionPayloads[0].didMarkBookFinished)
        #expect(!batch.savedSessionPayloads[1].didMarkBookFinished)
    }

    @Test func duplicateReadingSessionNotificationsAreDeduplicated() {
        let batch = ChallengeRefreshBatch(requests: [
            .readingSessionChanged(),
            .readingSessionChanged(),
            .readingSessionChanged()
        ])

        #expect(batch.requests.count == 1)
        #expect(batch.savedSessionPayloads.isEmpty)
        #expect(batch.postsReadingSessionChange)
        #expect(batch.readingSessionChangeNotificationCount == 1)
    }

    @Test func duplicateSavedSessionRequestsAreDeduplicatedBySessionID() {
        let snapshot = makeSessionSnapshot(index: 6, bookIndex: 12)
        let batch = ChallengeRefreshBatch(requests: [
            .readingSessionSaved(sessionSnapshot: snapshot, didMarkBookFinished: false),
            .readingSessionSaved(sessionSnapshot: snapshot, didMarkBookFinished: true)
        ])

        #expect(batch.requests.count == 1)
        #expect(batch.savedSessionPayloads.count == 1)
        #expect(!batch.savedSessionPayloads[0].didMarkBookFinished)
        #expect(batch.readingSessionChangeNotificationCount == 1)
    }

    private func makeSessionSnapshot(index: Int, bookIndex: Int) -> SavedReadingSessionSnapshot {
        let baseDate = Date(timeIntervalSince1970: 1_767_139_200)
        let start = baseDate.addingTimeInterval(TimeInterval(index * 3600))
        let end = start.addingTimeInterval(1_800)
        return SavedReadingSessionSnapshot(
            id: makeUUID(prefix: 1, index: index),
            bookID: makeUUID(prefix: 2, index: bookIndex),
            startedAt: start,
            endedAt: end,
            durationSeconds: 1_800,
            pagesRead: 24,
            note: " Session \(index) "
        )
    }

    private func makeUUID(prefix: Int, index: Int) -> UUID {
        let uuidString = String(format: "00000000-0000-0000-%04d-%012d", prefix, index)
        guard let uuid = UUID(uuidString: uuidString) else {
            fatalError("Invalid deterministic UUID: \(uuidString)")
        }
        return uuid
    }
}
