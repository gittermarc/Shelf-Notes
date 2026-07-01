import Foundation
@testable import Shelf_Notes

struct LargeReadingDatasetFixture {
    let books: [Book]
    let sessions: [ReadingSession]
    let challenges: [ChallengeRecord]
    let now: Date
    let calendar: Calendar
    let expectedCompletionCount: Int
    let expectedRereadCompletionCount: Int
    let expectedTimelineYears: [Int]
    let activeChallengeIDsByMetric: [ChallengeMetric: UUID]

    @MainActor var activeChallengeSnapshots: [ChallengeEngine.ChallengeRecordSnapshot] {
        challenges
            .filter { $0.completedAt == nil }
            .map { ChallengeEngine.ChallengeRecordSnapshot(from: $0) }
    }

    @MainActor var challengeSnapshot: ChallengeEngine.Snapshot {
        let sessionSnapshots = sessions.map { session in
            ChallengeEngine.SessionSnapshot(
                bookID: session.book?.id,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                durationSeconds: session.durationSeconds,
                pagesRead: session.pagesReadNormalized ?? 0,
                hasNote: !(session.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        let finishedBooks = books.flatMap { book in
            let hasUserNote = !book.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasUserRating = book.userRatingValues.contains { $0 > 0 }
            return ReadingCompletionRecordBuilder.records(from: book).map { completion in
                ChallengeEngine.FinishedBookSnapshot(
                    completion: completion,
                    hasUserNote: hasUserNote,
                    hasUserRating: hasUserRating
                )
            }
        }
        return ChallengeEngine.Snapshot(sessions: sessionSnapshots, finishedBooks: finishedBooks)
    }
}