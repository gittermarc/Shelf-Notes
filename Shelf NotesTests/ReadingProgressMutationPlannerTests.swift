import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingProgressMutationPlannerTests {

    @Test func pageDeltaUsesRemainingPagesAndCompletesAtLastPage() throws {
        let current = ReadingProgressSnapshot(
            unit: .pages,
            nativeValue: 70,
            totalValue: 100,
            pagesRead: 70,
            remainingPages: 30,
            normalizedProgress: 0.7,
            locator: nil,
            isCompleted: false
        )
        let update = ReadingProgressUpdate.pageDelta(
            30,
            occurredAt: Date(timeIntervalSince1970: 100)
        )

        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .standard
        ).get()

        #expect(plan.pagesDelta == 30)
        #expect(plan.startValue == 70)
        #expect(plan.endValue == 100)
        #expect(plan.endNormalizedProgress == 1)
        #expect(plan.eventNativeValue == 100)
        #expect(plan.didReachCompletion)
    }

    @Test func pageDeltaCannotExceedRemainingPages() {
        let current = ReadingProgressSnapshot(
            unit: .pages,
            nativeValue: 90,
            totalValue: 100,
            pagesRead: 90,
            remainingPages: 10,
            normalizedProgress: 0.9,
            locator: nil,
            isCompleted: false
        )

        let result = ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: .pageDelta(11, occurredAt: Date(timeIntervalSince1970: 200)),
            mode: .standard
        )

        guard case .failure(.pagesExceedRemaining(let remaining, let total)) = result else {
            #expect(Bool(false))
            return
        }
        #expect(remaining == 10)
        #expect(total == 100)
    }

    @Test func percentageNormalizesNativeAbsoluteValue() throws {
        let current = ReadingProgressSnapshot.unknown(unit: .percentage)
        let update = ReadingProgressUpdate.percentage(
            nativeValue: 45,
            totalValue: 100,
            occurredAt: Date(timeIntervalSince1970: 300)
        )

        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .standard
        ).get()

        #expect(plan.endValue == 45)
        #expect(plan.endNormalizedProgress == 0.45)
        #expect(plan.eventNativeValue == 45)
        #expect(plan.eventTotalValue == 100)
        #expect(plan.didReachCompletion == false)
    }

    @Test func standardModeRejectsBackwardAbsoluteProgress() {
        let current = ReadingProgressSnapshot(
            unit: .percentage,
            nativeValue: 80,
            totalValue: 100,
            pagesRead: nil,
            remainingPages: nil,
            normalizedProgress: 0.8,
            locator: nil,
            isCompleted: false
        )
        let update = ReadingProgressUpdate.percentage(
            normalizedProgress: 0.4,
            occurredAt: Date(timeIntervalSince1970: 400)
        )

        let result = ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .standard
        )

        guard case .failure(.progressWouldMoveBackward(let currentValue, let proposed)) = result else {
            #expect(Bool(false))
            return
        }
        #expect(currentValue == 0.8)
        #expect(proposed == 0.4)
    }

    @Test func correctionModeAllowsBackwardAbsoluteProgress() throws {
        let current = ReadingProgressSnapshot(
            unit: .percentage,
            nativeValue: 80,
            totalValue: 100,
            pagesRead: nil,
            remainingPages: nil,
            normalizedProgress: 0.8,
            locator: nil,
            isCompleted: false
        )
        let update = ReadingProgressUpdate.percentage(
            normalizedProgress: 0.4,
            occurredAt: Date(timeIntervalSince1970: 500)
        )

        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .correction
        ).get()

        #expect(plan.endNormalizedProgress == 0.4)
        #expect(plan.didReachCompletion == false)
    }

    @Test func locatorWithoutNormalizedValuePreservesKnownProgress() throws {
        let current = ReadingProgressSnapshot(
            unit: .locator,
            nativeValue: 12,
            totalValue: nil,
            pagesRead: nil,
            remainingPages: nil,
            normalizedProgress: 0.35,
            locator: "chapter:3",
            isCompleted: false
        )
        let update = ReadingProgressUpdate.locator(
            "epubcfi(/6/8!/4/2)",
            nativeValue: 18,
            occurredAt: Date(timeIntervalSince1970: 600)
        )

        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .standard
        ).get()

        #expect(plan.startLocator == "chapter:3")
        #expect(plan.endLocator == "epubcfi(/6/8!/4/2)")
        #expect(plan.endNormalizedProgress == 0.35)
        #expect(plan.eventNormalizedProgress == 0.35)
    }

    @Test func locatorWithoutAnyNormalizedValueDoesNotInventPercentage() throws {
        let current = ReadingProgressSnapshot.unknown(unit: .locator)
        let update = ReadingProgressUpdate.locator(
            "pdf:page:42",
            occurredAt: Date(timeIntervalSince1970: 700)
        )

        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .standard
        ).get()

        #expect(plan.endLocator == "pdf:page:42")
        #expect(plan.endNormalizedProgress == nil)
        #expect(plan.eventNormalizedProgress == nil)
    }

    @Test func nilUpdateCreatesNoProgressEvent() throws {
        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: .unknown(unit: .pages, totalValue: 300),
            update: nil,
            mode: .standard
        ).get()

        #expect(plan.pagesDelta == nil)
        #expect(plan.shouldPersistEvent == false)
        #expect(plan.didReachCompletion == false)
        #expect(plan.endNormalizedProgress == nil)
    }

    @Test func explicitCompletionFinishesWithoutInventingPages() throws {
        let current = ReadingProgressSnapshot(
            unit: .pages,
            nativeValue: 80,
            totalValue: 300,
            pagesRead: 80,
            remainingPages: 220,
            normalizedProgress: 80.0 / 300.0,
            locator: nil,
            isCompleted: false
        )
        let update = ReadingProgressUpdate.completed(
            occurredAt: Date(timeIntervalSince1970: 800)
        )

        let plan = try ReadingProgressMutationPlanner.makePlan(
            current: current,
            update: update,
            mode: .standard
        ).get()

        #expect(plan.pagesDelta == nil)
        #expect(plan.endNormalizedProgress == 1)
        #expect(plan.eventNativeValue == 80)
        #expect(plan.didReachCompletion)
    }

    @Test func invalidPercentageValueFailsSafely() {
        let update = ReadingProgressUpdate.percentage(
            nativeValue: .nan,
            normalizedProgress: .infinity,
            occurredAt: Date(timeIntervalSince1970: 900)
        )

        let result = ReadingProgressMutationPlanner.makePlan(
            current: .unknown(unit: .percentage),
            update: update,
            mode: .standard
        )

        #expect(result == .failure(.invalidPercentageValue))
    }
}
