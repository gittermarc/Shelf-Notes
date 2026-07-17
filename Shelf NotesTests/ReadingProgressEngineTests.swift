import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingProgressEngineTests {

    @Test func pageProgressUsesOnlyPositiveSessionValues() throws {
        let snapshot = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .pages,
                pageCountSnapshot: 400,
                sessionPageValues: [50, 0, -10, 70]
            )
        )

        #expect(snapshot.pagesRead == 120)
        #expect(snapshot.remainingPages == 280)
        #expect(snapshot.normalizedProgress == 0.3)
        #expect(snapshot.nativeValue == 120)
        #expect(snapshot.totalValue == 400)
    }

    @Test func pageProgressUsesReliableIntegralFallbackTotal() {
        let snapshot = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .pages,
                pageCountSnapshot: nil,
                totalValueSnapshot: 250,
                sessionPageValues: [25]
            )
        )

        #expect(snapshot.pagesRead == 25)
        #expect(snapshot.remainingPages == 225)
        #expect(snapshot.normalizedProgress == 0.1)
    }

    @Test func percentageProgressUsesNewestValidAbsoluteStateWithoutPages() {
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        let snapshot = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .percentage,
                updates: [
                    ReadingProgressUpdate(
                        stableIdentifier: "first",
                        occurredAt: firstDate,
                        unit: .percentage,
                        nativeValue: 20,
                        totalValue: 100
                    ),
                    ReadingProgressUpdate(
                        stableIdentifier: "second",
                        occurredAt: secondDate,
                        unit: .percentage,
                        nativeValue: 45,
                        totalValue: 100
                    )
                ]
            )
        )

        #expect(snapshot.normalizedProgress == 0.45)
        #expect(snapshot.nativeValue == 45)
        #expect(snapshot.pagesRead == nil)
        #expect(snapshot.remainingPages == nil)
    }

    @Test func equalDatedPercentageEventsUseStableIdentifierDeterministically() {
        let timestamp = Date(timeIntervalSince1970: 300)
        let lower = ReadingProgressUpdate(
            stableIdentifier: "event:a",
            occurredAt: timestamp,
            unit: .percentage,
            normalizedProgress: 0.2
        )
        let higher = ReadingProgressUpdate(
            stableIdentifier: "event:b",
            occurredAt: timestamp,
            unit: .percentage,
            normalizedProgress: 0.8
        )

        let firstOrder = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .percentage,
                updates: [higher, lower]
            )
        )
        let secondOrder = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .percentage,
                updates: [lower, higher]
            )
        )

        #expect(firstOrder.normalizedProgress == 0.8)
        #expect(secondOrder.normalizedProgress == 0.8)
    }

    @Test func locatorPreservesNativeValueWithoutInventingPercentage() {
        let timestamp = Date(timeIntervalSince1970: 400)
        let withoutNormalized = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .locator,
                updates: [
                    ReadingProgressUpdate(
                        stableIdentifier: "locator:a",
                        occurredAt: timestamp,
                        unit: .locator,
                        nativeValue: 12,
                        locator: "epubcfi(/6/4!/4/2)"
                    )
                ]
            )
        )
        let withNormalized = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .locator,
                updates: [
                    ReadingProgressUpdate(
                        stableIdentifier: "locator:b",
                        occurredAt: timestamp,
                        unit: .locator,
                        normalizedProgress: 0.42,
                        locator: "pdf:page:84"
                    )
                ]
            )
        )

        #expect(withoutNormalized.locator == "epubcfi(/6/4!/4/2)")
        #expect(withoutNormalized.normalizedProgress == nil)
        #expect(withNormalized.locator == "pdf:page:84")
        #expect(withNormalized.normalizedProgress == 0.42)
    }

    @Test func missingProgressRemainsUnknownInsteadOfZero() {
        let pages = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .pages,
                pageCountSnapshot: 300
            )
        )
        let none = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .none
            )
        )

        #expect(pages.pagesRead == nil)
        #expect(pages.remainingPages == 300)
        #expect(pages.normalizedProgress == nil)
        #expect(pages.hasMeasurableProgress == false)
        #expect(none.normalizedProgress == nil)
        #expect(none.hasMeasurableProgress == false)
    }

    @Test func finishedAttemptsAreAlwaysComplete() {
        for unit in ReadingProgressUnit.allCases {
            let snapshot = ReadingProgressEngine.snapshot(
                for: ReadingProgressAttemptSnapshot(
                    attemptID: UUID(),
                    status: .finished,
                    unit: unit,
                    pageCountSnapshot: 200
                )
            )

            #expect(snapshot.normalizedProgress == 1)
            #expect(snapshot.isCompleted)
        }
    }

    @Test func finishedPageAttemptsPreserveLoggedNativePages() {
        let snapshot = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .finished,
                unit: .pages,
                pageCountSnapshot: 200,
                sessionPageValues: [35]
            )
        )

        #expect(snapshot.pagesRead == 35)
        #expect(snapshot.nativeValue == 35)
        #expect(snapshot.remainingPages == 0)
        #expect(snapshot.normalizedProgress == 1)
    }

    @Test func invalidNewestPercentageValueIsIgnored() {
        let valid = ReadingProgressUpdate(
            stableIdentifier: "valid",
            occurredAt: Date(timeIntervalSince1970: 500),
            unit: .percentage,
            normalizedProgress: 0.55
        )
        let invalid = ReadingProgressUpdate(
            stableIdentifier: "invalid",
            occurredAt: Date(timeIntervalSince1970: 600),
            unit: .percentage,
            nativeValue: -.infinity,
            normalizedProgress: .nan
        )
        let snapshot = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .percentage,
                updates: [valid, invalid]
            )
        )

        #expect(snapshot.normalizedProgress == 0.55)
    }

    @Test func normalizedProgressIsClampedForEveryMeasuredUnit() {
        let timestamp = Date(timeIntervalSince1970: 700)
        let pages = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .pages,
                pageCountSnapshot: 100,
                sessionPageValues: [150]
            )
        )
        let percentage = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .percentage,
                updates: [
                    ReadingProgressUpdate(
                        stableIdentifier: "percentage:clamped",
                        occurredAt: timestamp,
                        unit: .percentage,
                        nativeValue: 125
                    )
                ]
            )
        )
        let locator = ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: .active,
                unit: .locator,
                updates: [
                    ReadingProgressUpdate(
                        stableIdentifier: "locator:clamped",
                        occurredAt: timestamp,
                        unit: .locator,
                        normalizedProgress: -0.5,
                        locator: "chapter:4"
                    )
                ]
            )
        )

        #expect(pages.normalizedProgress == 1)
        #expect(percentage.normalizedProgress == 1)
        #expect(percentage.totalValue == nil)
        #expect(locator.normalizedProgress == 0)
    }
}