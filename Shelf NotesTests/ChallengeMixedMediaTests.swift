import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeMixedMediaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    @Test func mixedSessionsKeepUniversalAndPageMetricsSeparate() {
        let window = date(2026, 7, 1, 0)..<date(2026, 7, 2, 0)
        let sessions = [
            ChallengeEngine.SessionSnapshot(
                bookID: fixedID(1),
                startedAt: date(2026, 7, 1, 8),
                endedAt: date(2026, 7, 1, 8, 20),
                durationSeconds: 20 * 60,
                pagesRead: 30,
                progressUnitRawValue: ReadingProgressUnit.pages.rawValue,
                originRawValue: ReadingSessionOrigin.timer.rawValue
            ),
            ChallengeEngine.SessionSnapshot(
                bookID: fixedID(2),
                startedAt: date(2026, 7, 1, 10),
                endedAt: date(2026, 7, 1, 10, 15),
                durationSeconds: 15 * 60,
                pagesRead: 0,
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                originRawValue: ReadingSessionOrigin.quickLog.rawValue,
                startValue: 20,
                endValue: 40,
                startNormalizedProgress: 0.2,
                endNormalizedProgress: 0.4
            ),
            ChallengeEngine.SessionSnapshot(
                bookID: fixedID(3),
                startedAt: date(2026, 7, 1, 12),
                endedAt: date(2026, 7, 1, 12, 10),
                durationSeconds: 10 * 60,
                pagesRead: 0,
                progressUnitRawValue: ReadingProgressUnit.locator.rawValue,
                originRawValue: ReadingSessionOrigin.quickLog.rawValue,
                startNormalizedProgress: 0.3,
                endNormalizedProgress: 0.5,
                startLocator: "chapter-3",
                endLocator: "chapter-5"
            ),
            ChallengeEngine.SessionSnapshot(
                bookID: fixedID(4),
                startedAt: date(2026, 7, 1, 14),
                endedAt: date(2026, 7, 1, 14, 5),
                durationSeconds: 5 * 60,
                pagesRead: 0,
                progressUnitRawValue: ReadingProgressUnit.none.rawValue,
                originRawValue: ReadingSessionOrigin.quickLog.rawValue
            ),
            ChallengeEngine.SessionSnapshot(
                bookID: fixedID(5),
                startedAt: date(2026, 7, 1, 16),
                endedAt: date(2026, 7, 1, 17),
                durationSeconds: 60 * 60,
                pagesRead: 0,
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                originRawValue: ReadingSessionOrigin.providerImport.rawValue,
                startNormalizedProgress: 0.4,
                endNormalizedProgress: 0.6
            )
        ]
        let snapshot = ChallengeEngine.Snapshot(sessions: sessions, finishedBooks: [])

        #expect(progress(.readingMinutes, window: window, snapshot: snapshot) == 50)
        #expect(progress(.sessions, window: window, snapshot: snapshot) == 4)
        #expect(progress(.readingDays, window: window, snapshot: snapshot) == 1)
        #expect(progress(.pagesRead, window: window, snapshot: snapshot) == 30)
        #expect(progress(.booksProgressed, window: window, snapshot: snapshot) == 4)
    }

    @Test func providerEventsOnlyContributeRealDeduplicatedBookProgress() {
        let window = date(2026, 7, 1, 0)..<date(2026, 7, 8, 0)
        let bookA = fixedID(10)
        let bookB = fixedID(11)
        let bookC = fixedID(12)
        let bookD = fixedID(13)
        let events = [
            event(bookID: bookA, occurredAt: date(2026, 6, 30, 12), unit: .percentage, normalized: 0.2, key: "a-20"),
            event(bookID: bookA, occurredAt: date(2026, 7, 2, 12), unit: .percentage, normalized: 0.4, key: "a-40"),
            event(bookID: bookA, occurredAt: date(2026, 7, 2, 12), unit: .percentage, normalized: 0.4, key: "a-40"),
            event(bookID: bookB, occurredAt: date(2026, 6, 30, 12), unit: .percentage, normalized: 0.5, key: "shared-key"),
            event(bookID: bookB, occurredAt: date(2026, 7, 3, 12), unit: .percentage, normalized: 0.4, key: "b-40"),
            event(bookID: bookC, occurredAt: date(2026, 7, 4, 12), unit: .locator, locator: "chapter-8", key: "locator-only"),
            event(bookID: bookD, occurredAt: date(2026, 6, 30, 12), unit: .pages, native: 10, key: "shared-key"),
            event(bookID: bookD, occurredAt: date(2026, 7, 5, 12), unit: .pages, native: 30, key: "d-30")
        ]
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [],
            finishedBooks: [],
            progressEvents: events
        )

        #expect(progress(.readingMinutes, window: window, snapshot: snapshot) == 0)
        #expect(progress(.sessions, window: window, snapshot: snapshot) == 0)
        #expect(progress(.readingDays, window: window, snapshot: snapshot) == 0)
        #expect(progress(.pagesRead, window: window, snapshot: snapshot) == 0)
        #expect(progress(.booksProgressed, window: window, snapshot: snapshot) == 2)
    }

    @Test func percentageHintsNeverExposePageLanguage() {
        let items = [
            dashboardItem(metric: .pagesRead, progressValue: 20, targetValue: 100),
            dashboardItem(metric: .booksProgressed, progressValue: 1, targetValue: 3),
            dashboardItem(metric: .readingMinutes, progressValue: 20, targetValue: 60)
        ]

        let hints = ChallengeActionHintBuilder.makeSessionHints(
            from: items,
            bookTitle: "Kindle Book",
            remainingPages: 84,
            progressUnit: .percentage,
            limit: 10
        )

        #expect(hints.map(\.metric).contains(.pagesRead) == false)
        #expect(hints.map(\.metric).contains(.booksProgressed))
        #expect(hints.allSatisfy { !$0.message.contains("Seiten") && !$0.detail.contains("Seiten") })
        #expect(hints.first(where: { $0.metric == .booksProgressed })?.message.contains("Prozentstand") == true)
    }

    @Test func physicalPageHintsKeepRemainingPageGuidance() {
        let hints = ChallengeActionHintBuilder.makeSessionHints(
            from: [dashboardItem(metric: .pagesRead, progressValue: 20, targetValue: 100)],
            bookTitle: "Physical Book",
            remainingPages: 84,
            progressUnit: .pages,
            limit: 10
        )

        #expect(hints.count == 1)
        #expect(hints[0].message.contains("84 Seiten"))
    }

    private func progress(
        _ metric: ChallengeMetric,
        window: Range<Date>,
        snapshot: ChallengeEngine.Snapshot
    ) -> Int {
        ChallengeEngine.computeProgress(metric: metric, window: window, snapshot: snapshot).value
    }

    private func event(
        bookID: UUID,
        occurredAt: Date,
        unit: ReadingProgressUnit,
        native: Double? = nil,
        normalized: Double? = nil,
        locator: String? = nil,
        key: String
    ) -> ChallengeEngine.ProgressEventSnapshot {
        ChallengeEngine.ProgressEventSnapshot(
            bookID: bookID,
            occurredAt: occurredAt,
            progressUnitRawValue: unit.rawValue,
            nativeValue: native,
            normalizedProgress: normalized,
            locator: locator,
            deduplicationKey: key
        )
    }

    private func dashboardItem(
        metric: ChallengeMetric,
        progressValue: Int,
        targetValue: Int
    ) -> ChallengeDashboardItem {
        ChallengeDashboardItem(
            id: UUID(),
            kind: .weekly,
            metric: metric,
            title: "Test Challenge",
            detail: "Test detail",
            targetValue: targetValue,
            periodLabel: "01.07.–07.07.",
            periodStart: date(2026, 7, 1, 0),
            periodEnd: date(2026, 7, 8, 0),
            progress: ChallengeEngine.ChallengeProgress(value: progressValue, unitSuffix: metric.unitSuffix),
            status: .active,
            canReroll: true,
            timeRemainingText: "noch 2 Tage",
            deadlineText: "bis 07.07.",
            progressText: "\(progressValue)/\(targetValue) \(metric.unitSuffix)",
            remainingText: "Noch \(max(0, targetValue - progressValue)) \(metric.unitSuffix)",
            motivationText: "Dranbleiben.",
            difficultyText: "Dranbleiben",
            rewardText: "Belohnungstext."
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
