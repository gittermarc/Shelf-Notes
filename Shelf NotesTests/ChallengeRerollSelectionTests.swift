import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeRerollSelectionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test func rerollReplacementUsesDifferentMetricWhenAlternativesExist() {
        let snapshot = ChallengeEngine.Snapshot(sessions: [], finishedBookReadTo: [])
        let replacement = ChallengeEngine.rerollReplacement(
            kind: .weekly,
            current: .readingMinutes,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            snapshot: snapshot,
            challengeID: UUID(uuidString: "00000000-0000-0000-0000-000000000501") ?? UUID(),
            rerollsUsed: 0
        )

        #expect(replacement.metric != .readingMinutes)
        #expect(ChallengeEngine.allowedMetrics(for: .weekly).contains(replacement.metric))
    }

    @Test func rerollReplacementAvoidsAlreadyFinishedAlternativesWhenPossible() {
        let start = date(2026, 6, 1)
        let end = date(2026, 6, 8)
        let sessions = [
            ChallengeEngine.SessionSnapshot(
                startedAt: date(2026, 6, 2, 8),
                endedAt: date(2026, 6, 2, 10),
                durationSeconds: 2 * 60 * 60,
                pagesRead: 500
            ),
            ChallengeEngine.SessionSnapshot(
                startedAt: date(2026, 6, 3, 8),
                endedAt: date(2026, 6, 3, 9),
                durationSeconds: 60 * 60,
                pagesRead: 0
            )
        ]
        let snapshot = ChallengeEngine.Snapshot(sessions: sessions, finishedBookReadTo: [])

        let replacement = ChallengeEngine.rerollReplacement(
            kind: .weekly,
            current: .readingMinutes,
            periodStart: start,
            periodEnd: end,
            snapshot: snapshot,
            challengeID: UUID(uuidString: "00000000-0000-0000-0000-000000000502") ?? UUID(),
            rerollsUsed: 0
        )

        let progress = ChallengeEngine.computeProgress(metric: replacement.metric, window: start..<end, snapshot: snapshot)
        #expect(progress.value < replacement.targetValue)
    }
}
