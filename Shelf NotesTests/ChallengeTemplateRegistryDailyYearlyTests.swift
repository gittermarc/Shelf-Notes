import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeTemplateRegistryDailyYearlyTests {
    @Test func dailyTemplatesAreActionable() {
        let templates = ChallengeTemplateRegistry.templates(for: .daily)
        let metrics = Set(templates.map(\.metric))

        #expect(templates.count >= 5)
        #expect(templates.allSatisfy { $0.kind == .daily })
        #expect(metrics.contains(.readingMinutes))
        #expect(metrics.contains(.sessions))
        #expect(metrics.contains(.readingDays))
        #expect(metrics.contains(.sessionNotes))
        #expect(ChallengeTemplateRegistry.template(kind: .daily, metric: .pagesRead)?.requiresPageHistory ?? false)
        #expect(templates.allSatisfy { $0.minimumTarget > 0 })
        #expect(templates.allSatisfy { $0.maximumTarget >= $0.minimumTarget })
        #expect(templates.allSatisfy { $0.fallbackTarget >= $0.minimumTarget })
        #expect(templates.allSatisfy { $0.fallbackTarget <= $0.maximumTarget })
        #expect(templates.allSatisfy { $0.targetStep > 0 })
    }

    @Test func yearlyTemplatesAreQuestSized() {
        let templates = ChallengeTemplateRegistry.templates(for: .yearly)
        let metrics = Set(templates.map(\.metric))

        #expect(templates.count >= 7)
        #expect(templates.allSatisfy { $0.kind == .yearly })
        #expect(metrics.contains(.readingDays))
        #expect(metrics.contains(.booksFinished))
        #expect(metrics.contains(.readingMinutes))
        #expect(metrics.contains(.sessions))
        #expect(metrics.contains(.pagesRead))
        #expect(metrics.contains(.sessionNotes))
        #expect(metrics.contains(.finishedBooksRated))
        #expect(metrics.contains(.finishedBooksNoted))
        #expect(ChallengeTemplateRegistry.template(kind: .yearly, metric: .pagesRead)?.requiresPageHistory ?? false)
        #expect(ChallengeTemplateRegistry.template(kind: .yearly, metric: .finishedBooksRated)?.requiresFinishedBookHistory ?? false)
        #expect(templates.allSatisfy { $0.minimumTarget > 0 })
        #expect(templates.allSatisfy { $0.maximumTarget >= $0.minimumTarget })
        #expect(templates.allSatisfy { $0.fallbackTarget >= $0.minimumTarget })
        #expect(templates.allSatisfy { $0.fallbackTarget <= $0.maximumTarget })
        #expect(templates.allSatisfy { $0.targetStep > 0 })
    }

    @Test func dailyTargetsStaySmallWithFourteenDayBaseline() {
        let baseline = ChallengeEngine.BaselineStats(
            minutes: 420,
            activeDays: 10,
            sessions: 18,
            pagesRead: 700,
            finishedBooks: 1,
            shortSessions: 6,
            progressedBooks: 3,
            sessionNotes: 4,
            ratedFinishedBooks: 1,
            notedFinishedBooks: 1
        )

        let minutes = ChallengeTemplateRegistry.template(kind: .daily, metric: .readingMinutes)
        let sessions = ChallengeTemplateRegistry.template(kind: .daily, metric: .sessions)
        let readingDays = ChallengeTemplateRegistry.template(kind: .daily, metric: .readingDays)
        let pages = ChallengeTemplateRegistry.template(kind: .daily, metric: .pagesRead)

        #expect((minutes?.target(from: baseline.value(for: .readingMinutes, kind: .daily)) ?? 0) == 35)
        #expect((sessions?.target(from: baseline.value(for: .sessions, kind: .daily)) ?? 0) == 1)
        #expect((readingDays?.target(from: baseline.value(for: .readingDays, kind: .daily)) ?? 0) == 1)
        #expect((pages?.target(from: baseline.value(for: .pagesRead, kind: .daily)) ?? 0) == 55)
    }

    @Test func targetCalculationDoesNotOverRoundDecimalProducts() {
        #expect(ChallengeTemplateMath.scaledCeiling(baselineValue: 50, multiplier: 1.1) == 55)
        #expect(ChallengeTemplateMath.scaledCeiling(baselineValue: 30, multiplier: 1.1) == 33)
        #expect(ChallengeTemplateMath.scaledCeiling(baselineValue: 3, multiplier: 1.1) == 4)
        #expect(ChallengeTemplateMath.scaledCeiling(baselineValue: 10, multiplier: 1.0) == 10)
    }

    @Test func yearlyFallbackTargetsAreLongTermQuests() {
        let emptyBaseline = ChallengeEngine.BaselineStats(
            minutes: 0,
            activeDays: 0,
            sessions: 0,
            pagesRead: 0,
            finishedBooks: 0
        )

        let readingDays = ChallengeTemplateRegistry.template(kind: .yearly, metric: .readingDays)
        let books = ChallengeTemplateRegistry.template(kind: .yearly, metric: .booksFinished)
        let minutes = ChallengeTemplateRegistry.template(kind: .yearly, metric: .readingMinutes)
        let sessions = ChallengeTemplateRegistry.template(kind: .yearly, metric: .sessions)
        let notes = ChallengeTemplateRegistry.template(kind: .yearly, metric: .sessionNotes)

        #expect((readingDays?.target(from: emptyBaseline.value(for: .readingDays, kind: .yearly)) ?? 0) == 100)
        #expect((books?.target(from: emptyBaseline.value(for: .booksFinished, kind: .yearly)) ?? 0) == 12)
        #expect((minutes?.target(from: emptyBaseline.value(for: .readingMinutes, kind: .yearly)) ?? 0) == 5_100)
        #expect((sessions?.target(from: emptyBaseline.value(for: .sessions, kind: .yearly)) ?? 0) == 100)
        #expect((notes?.target(from: emptyBaseline.value(for: .sessionNotes, kind: .yearly)) ?? 0) == 25)
    }
}
