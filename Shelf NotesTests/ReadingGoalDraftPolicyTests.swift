import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingGoalDraftPolicyTests {
    @Test func loadingMissingGoalUsesDefaultDraftWithoutPersistence() {
        let draft = ReadingGoalDraftPolicy.draftForLoading(year: 2026, goals: [])

        #expect(draft.targetCount == ReadingGoalDraftPolicy.defaultTargetCount)
        #expect(draft.needsPersistence == false)
    }

    @Test func loadingExistingGoalUsesPersistedTargetWithoutPersistence() {
        let goal = ReadingGoal(year: 2026, targetCount: 24)

        let draft = ReadingGoalDraftPolicy.draftForLoading(year: 2026, goals: [goal])

        #expect(draft.targetCount == 24)
        #expect(draft.needsPersistence == false)
    }

    @Test func loadingExistingGoalNormalizesInvalidTargetWithoutPersistence() {
        let goal = ReadingGoal(year: 2026, targetCount: 0)

        let draft = ReadingGoalDraftPolicy.draftForLoading(year: 2026, goals: [goal])

        #expect(draft.targetCount == 1)
        #expect(draft.needsPersistence == false)
    }

    @Test func userEditForMissingGoalRequestsInsert() {
        let change = ReadingGoalDraftPolicy.changeForUserTargetEdit(
            year: 2026,
            targetCount: 18,
            goals: []
        )

        #expect(change == .insert(year: 2026, targetCount: 18))
    }

    @Test func userEditForUnchangedGoalSkipsPersistence() {
        let goal = ReadingGoal(year: 2026, targetCount: 18)

        let change = ReadingGoalDraftPolicy.changeForUserTargetEdit(
            year: 2026,
            targetCount: 18,
            goals: [goal]
        )

        #expect(change == nil)
    }

    @Test func userEditForChangedGoalRequestsUpdate() {
        let goal = ReadingGoal(year: 2026, targetCount: 18)

        let change = ReadingGoalDraftPolicy.changeForUserTargetEdit(
            year: 2026,
            targetCount: 19,
            goals: [goal]
        )

        #expect(change == .update(year: 2026, targetCount: 19))
    }
}
