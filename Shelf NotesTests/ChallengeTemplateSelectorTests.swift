import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeTemplateSelectorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    @Test func registryContainsWeeklyAndMonthlyTemplates() {
        #expect(ChallengeTemplateRegistry.templates(for: .weekly).count >= 5)
        #expect(ChallengeTemplateRegistry.templates(for: .monthly).count >= 7)
        #expect(ChallengeTemplateRegistry.template(kind: .weekly, metric: .shortSessions) != nil)
        #expect(ChallengeTemplateRegistry.template(kind: .monthly, metric: .finishedBooksRated) != nil)
    }

    @Test func selectorAvoidsRecentMetricsWhenAlternativesExist() {
        let baseline = ChallengeEngine.BaselineStats(
            minutes: 480,
            activeDays: 12,
            sessions: 18,
            pagesRead: 600,
            finishedBooks: 2,
            shortSessions: 7,
            progressedBooks: 3,
            sessionNotes: 4,
            ratedFinishedBooks: 1,
            notedFinishedBooks: 1
        )

        let selected = ChallengeTemplateSelector.selectTemplate(
            kind: .monthly,
            baseline: baseline,
            recentMetrics: [.readingMinutes, .booksFinished],
            periodStart: date(2026, 6, 1)
        )

        #expect(selected.metric != .readingMinutes)
        #expect(selected.metric != .booksFinished)
    }

    @Test func replacementKeepsDifferentMetric() {
        let baseline = ChallengeEngine.BaselineStats(
            minutes: 240,
            activeDays: 8,
            sessions: 12,
            pagesRead: 320,
            finishedBooks: 1,
            shortSessions: 4,
            progressedBooks: 2,
            sessionNotes: 2,
            ratedFinishedBooks: 1,
            notedFinishedBooks: 1
        )

        let replacement = ChallengeTemplateSelector.replacementTemplate(
            kind: .weekly,
            currentMetric: .readingMinutes,
            baseline: baseline,
            recentMetrics: [.readingDays],
            challengeID: UUID(uuidString: "00000000-0000-0000-0000-000000001101") ?? UUID(),
            rerollsUsed: 0
        )

        #expect(replacement.metric != .readingMinutes)
    }
}
