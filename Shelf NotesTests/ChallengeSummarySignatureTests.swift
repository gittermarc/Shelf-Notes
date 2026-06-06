import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeSummarySignatureTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @MainActor
    private func makeChallenge(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        kind: ChallengeKind = .weekly,
        metric: ChallengeMetric = .readingMinutes,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        targetValue: Int = 30,
        createdAt: Date? = nil
    ) -> ChallengeRecord {
        let record = ChallengeRecord(
            kind: kind,
            metric: metric,
            periodStart: periodStart ?? date(2026, 5, 18),
            periodEnd: periodEnd ?? date(2026, 5, 25),
            title: "Read more",
            detail: "Read for a focused amount of time.",
            targetValue: targetValue
        )
        record.id = id
        if let createdAt {
            record.createdAt = createdAt
        }
        return record
    }

    @Test @MainActor func signatureChangesWhenChallengeIsCompleted() {
        let challenge = makeChallenge()
        let before = ChallengeSummarySignature(challenges: [challenge])

        challenge.completedAt = date(2026, 5, 20)
        let after = ChallengeSummarySignature(challenges: [challenge])

        #expect(before != after)
    }

    @Test @MainActor func signatureChangesWhenChallengeIsAcknowledged() {
        let challenge = makeChallenge()
        challenge.completedAt = date(2026, 5, 20)
        let before = ChallengeSummarySignature(challenges: [challenge])

        challenge.acknowledgedAt = date(2026, 5, 21)
        let after = ChallengeSummarySignature(challenges: [challenge])

        #expect(before != after)
    }

    @Test @MainActor func signatureChangesWhenTargetValueOrPeriodChanges() {
        let challenge = makeChallenge()
        let original = ChallengeSummarySignature(challenges: [challenge])

        challenge.targetValue = 45
        let targetChanged = ChallengeSummarySignature(challenges: [challenge])

        challenge.periodStart = date(2026, 5, 19)
        challenge.periodEnd = date(2026, 5, 26)
        let periodChanged = ChallengeSummarySignature(challenges: [challenge])

        #expect(original != targetChanged)
        #expect(targetChanged != periodChanged)
    }

    @Test @MainActor func signatureChangesWhenRerollUpdatesChallengeContent() {
        let challenge = makeChallenge()
        let before = ChallengeSummarySignature(challenges: [challenge])

        challenge.metric = .pagesRead
        challenge.title = "Read pages"
        challenge.detail = "Read a concrete page target."
        challenge.rerollsUsed = 1
        challenge.rerolledAt = date(2026, 5, 20)
        let after = ChallengeSummarySignature(challenges: [challenge])

        #expect(before != after)
    }

    @Test @MainActor func signatureIsStableWhenChallengeOrderChanges() {
        let first = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            kind: .weekly,
            metric: .readingMinutes,
            periodStart: date(2026, 5, 18),
            periodEnd: date(2026, 5, 25),
            targetValue: 30
        )
        let second = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            kind: .monthly,
            metric: .booksFinished,
            periodStart: date(2026, 5, 1),
            periodEnd: date(2026, 6, 1),
            targetValue: 2
        )

        let ordered = ChallengeSummarySignature(challenges: [first, second])
        let reordered = ChallengeSummarySignature(challenges: [second, first])

        #expect(ordered == reordered)
    }

    @Test @MainActor func signatureIgnoresInvisibleDuplicateForSamePeriod() {
        let retained = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID(),
            kind: .weekly,
            metric: .readingMinutes,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            targetValue: 30,
            createdAt: date(2026, 5, 20)
        )
        let invisibleDuplicate = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102") ?? UUID(),
            kind: .weekly,
            metric: .pagesRead,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            targetValue: 80,
            createdAt: date(2026, 5, 21)
        )

        let withoutDuplicate = ChallengeSummarySignature(challenges: [retained])
        let withInvisibleDuplicate = ChallengeSummarySignature(challenges: [retained, invisibleDuplicate])

        #expect(withoutDuplicate == withInvisibleDuplicate)
    }
}
