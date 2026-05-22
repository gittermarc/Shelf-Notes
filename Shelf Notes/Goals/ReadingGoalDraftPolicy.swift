import Foundation

struct ReadingGoalDraft {
    let targetCount: Int
    let needsPersistence: Bool
}

enum ReadingGoalPersistenceChange: Equatable {
    case insert(year: Int, targetCount: Int)
    case update(year: Int, targetCount: Int)
}

enum ReadingGoalDraftPolicy {
    static let defaultTargetCount = 50

    static func normalizedTargetCount(_ targetCount: Int) -> Int {
        max(targetCount, 1)
    }

    static func draftForLoading(year: Int, goals: [ReadingGoal]) -> ReadingGoalDraft {
        draftForLoading(
            year: year,
            existingGoal: goals.first(where: { $0.year == year })
        )
    }

    static func draftForLoading(year: Int, existingGoal: ReadingGoal?) -> ReadingGoalDraft {
        guard let existingGoal else {
            return ReadingGoalDraft(
                targetCount: defaultTargetCount,
                needsPersistence: false
            )
        }

        return ReadingGoalDraft(
            targetCount: normalizedTargetCount(existingGoal.targetCount),
            needsPersistence: false
        )
    }

    static func changeForUserTargetEdit(
        year: Int,
        targetCount: Int,
        goals: [ReadingGoal]
    ) -> ReadingGoalPersistenceChange? {
        changeForUserTargetEdit(
            year: year,
            targetCount: targetCount,
            existingGoal: goals.first(where: { $0.year == year })
        )
    }

    static func changeForUserTargetEdit(
        year: Int,
        targetCount: Int,
        existingGoal: ReadingGoal?
    ) -> ReadingGoalPersistenceChange? {
        let normalizedTargetCount = normalizedTargetCount(targetCount)

        guard let existingGoal else {
            return .insert(year: year, targetCount: normalizedTargetCount)
        }

        guard existingGoal.targetCount != normalizedTargetCount else {
            return nil
        }

        return .update(year: year, targetCount: normalizedTargetCount)
    }
}
