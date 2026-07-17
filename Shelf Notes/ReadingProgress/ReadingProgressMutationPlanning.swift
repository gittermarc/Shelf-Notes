//
//  ReadingProgressMutationPlanning.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingProgressMutationPlanner {
    private static let regressionTolerance = 0.000_000_1

    static func makePlan(
        current: ReadingProgressSnapshot,
        update: ReadingProgressUpdate?,
        mode: ReadingProgressMutationMode,
        allowsPageOverflow: Bool = false,
        allowsAbsolutePageValue: Bool = false
    ) -> Result<ReadingProgressMutationPlan, ReadingProgressMutationValidationError> {
        guard let update else {
            return .success(.noUpdate(unit: current.unit))
        }

        if update.semantics == .completion {
            return .success(completionPlan(current: current, update: update))
        }

        if current.unit != .none, update.unit != current.unit {
            return .failure(.progressUnitMismatch(expected: current.unit, actual: update.unit))
        }

        switch update.unit {
        case .pages:
            switch update.semantics {
            case .delta:
                return pageDeltaPlan(
                    current: current,
                    update: update,
                    allowsPageOverflow: allowsPageOverflow
                )
            case .absolute where allowsAbsolutePageValue:
                return absolutePagePlan(current: current, update: update, mode: mode)
            case .absolute:
                return .failure(.invalidPageDelta)
            case .completion:
                return .success(completionPlan(current: current, update: update))
            }
        case .percentage:
            return percentagePlan(current: current, update: update, mode: mode)
        case .locator:
            return locatorPlan(current: current, update: update, mode: mode)
        case .none:
            return .failure(.invalidPercentageValue)
        }
    }

    private static func pageDeltaPlan(
        current: ReadingProgressSnapshot,
        update: ReadingProgressUpdate,
        allowsPageOverflow: Bool
    ) -> Result<ReadingProgressMutationPlan, ReadingProgressMutationValidationError> {
        guard let pages = positiveIntegralInt(update.nativeValue) else {
            return .failure(.invalidPageDelta)
        }

        let startPages = max(0, current.pagesRead ?? integralInt(current.nativeValue) ?? 0)
        let totalPages = positiveIntegralInt(current.totalValue ?? update.totalValue)

        if let totalPages, allowsPageOverflow == false {
            let remaining = max(0, totalPages - startPages)
            if remaining == 0 {
                return .failure(.noRemainingPages(total: totalPages))
            }
            if pages > remaining {
                return .failure(.pagesExceedRemaining(remaining: remaining, total: totalPages))
            }
        }

        let endPages = addingWithoutOverflow(startPages, pages)
        let normalized = totalPages.map { clamp(Double(endPages) / Double($0)) }
        let completed = totalPages.map { endPages >= $0 } ?? false

        return .success(
            ReadingProgressMutationPlan(
                unit: .pages,
                update: update,
                pagesDelta: pages,
                startValue: startPages > 0 ? Double(startPages) : nil,
                endValue: Double(endPages),
                startNormalizedProgress: current.normalizedProgress,
                endNormalizedProgress: normalized,
                startLocator: nil,
                endLocator: nil,
                eventNativeValue: Double(endPages),
                eventTotalValue: totalPages.map(Double.init),
                eventNormalizedProgress: normalized,
                eventLocator: nil,
                didReachCompletion: completed,
                shouldPersistEvent: true
            )
        )
    }

    private static func absolutePagePlan(
        current: ReadingProgressSnapshot,
        update: ReadingProgressUpdate,
        mode: ReadingProgressMutationMode
    ) -> Result<ReadingProgressMutationPlan, ReadingProgressMutationValidationError> {
        guard let pages = nonNegativeIntegralInt(update.nativeValue) else {
            return .failure(.invalidAbsolutePageValue)
        }

        let totalPages = positiveIntegralInt(update.totalValue ?? current.totalValue)
        let normalized = update.normalizedProgress.flatMap(finite).map(clamp)
            ?? totalPages.map { clamp(Double(pages) / Double($0)) }

        if let validation = regressionValidation(
            current: current.normalizedProgress,
            proposed: normalized,
            mode: mode
        ) {
            return .failure(validation)
        }

        return .success(
            ReadingProgressMutationPlan(
                unit: .pages,
                update: update,
                pagesDelta: nil,
                startValue: current.nativeValue,
                endValue: Double(pages),
                startNormalizedProgress: current.normalizedProgress,
                endNormalizedProgress: normalized,
                startLocator: nil,
                endLocator: nil,
                eventNativeValue: Double(pages),
                eventTotalValue: totalPages.map(Double.init),
                eventNormalizedProgress: normalized,
                eventLocator: nil,
                didReachCompletion: totalPages.map { pages >= $0 } ?? (normalized == 1),
                shouldPersistEvent: true
            )
        )
    }

    private static func percentagePlan(
        current: ReadingProgressSnapshot,
        update: ReadingProgressUpdate,
        mode: ReadingProgressMutationMode
    ) -> Result<ReadingProgressMutationPlan, ReadingProgressMutationValidationError> {
        guard let normalized = normalizedPercentage(update) else {
            return .failure(.invalidPercentageValue)
        }

        if let validation = regressionValidation(
            current: current.normalizedProgress,
            proposed: normalized,
            mode: mode
        ) {
            return .failure(validation)
        }

        let total = positiveFinite(update.totalValue) ?? positiveFinite(current.totalValue)
        let native = nonNegativeFinite(update.nativeValue)
            ?? normalized * (total ?? 100)

        return .success(
            ReadingProgressMutationPlan(
                unit: .percentage,
                update: update,
                pagesDelta: nil,
                startValue: current.nativeValue,
                endValue: native,
                startNormalizedProgress: current.normalizedProgress,
                endNormalizedProgress: normalized,
                startLocator: current.locator,
                endLocator: normalizedLocator(update.locator) ?? current.locator,
                eventNativeValue: native,
                eventTotalValue: total,
                eventNormalizedProgress: normalized,
                eventLocator: normalizedLocator(update.locator),
                didReachCompletion: normalized >= 1,
                shouldPersistEvent: true
            )
        )
    }

    private static func locatorPlan(
        current: ReadingProgressSnapshot,
        update: ReadingProgressUpdate,
        mode: ReadingProgressMutationMode
    ) -> Result<ReadingProgressMutationPlan, ReadingProgressMutationValidationError> {
        guard let locator = normalizedLocator(update.locator) else {
            return .failure(.missingLocator)
        }

        let suppliedNormalized = update.normalizedProgress.flatMap(finite).map(clamp)
        if let validation = regressionValidation(
            current: current.normalizedProgress,
            proposed: suppliedNormalized,
            mode: mode
        ) {
            return .failure(validation)
        }

        let preservedNormalized = suppliedNormalized ?? current.normalizedProgress
        let native = finite(update.nativeValue) ?? current.nativeValue ?? 0
        let total = positiveFinite(update.totalValue) ?? positiveFinite(current.totalValue)

        return .success(
            ReadingProgressMutationPlan(
                unit: .locator,
                update: update,
                pagesDelta: nil,
                startValue: current.nativeValue,
                endValue: native,
                startNormalizedProgress: current.normalizedProgress,
                endNormalizedProgress: preservedNormalized,
                startLocator: current.locator,
                endLocator: locator,
                eventNativeValue: native,
                eventTotalValue: total,
                eventNormalizedProgress: preservedNormalized,
                eventLocator: locator,
                didReachCompletion: preservedNormalized == 1,
                shouldPersistEvent: true
            )
        )
    }

    private static func completionPlan(
        current: ReadingProgressSnapshot,
        update: ReadingProgressUpdate
    ) -> ReadingProgressMutationPlan {
        let unit = update.unit == .none ? current.unit : update.unit
        let native: Double
        if let currentNative = finite(current.nativeValue) {
            native = currentNative
        } else if unit == .percentage {
            native = 100
        } else {
            native = 0
        }

        return ReadingProgressMutationPlan(
            unit: unit,
            update: update,
            pagesDelta: nil,
            startValue: current.nativeValue,
            endValue: current.nativeValue,
            startNormalizedProgress: current.normalizedProgress,
            endNormalizedProgress: 1,
            startLocator: current.locator,
            endLocator: current.locator,
            eventNativeValue: native,
            eventTotalValue: current.totalValue,
            eventNormalizedProgress: 1,
            eventLocator: current.locator,
            didReachCompletion: true,
            shouldPersistEvent: true
        )
    }

    private static func normalizedPercentage(_ update: ReadingProgressUpdate) -> Double? {
        if let normalized = update.normalizedProgress.flatMap(finite) {
            return clamp(normalized)
        }

        guard let native = nonNegativeFinite(update.nativeValue) else {
            return nil
        }

        let total = positiveFinite(update.totalValue) ?? 100
        return clamp(native / total)
    }

    private static func regressionValidation(
        current: Double?,
        proposed: Double?,
        mode: ReadingProgressMutationMode
    ) -> ReadingProgressMutationValidationError? {
        guard mode == .standard,
              let current = current.flatMap(finite).map(clamp),
              let proposed = proposed.flatMap(finite).map(clamp),
              proposed + regressionTolerance < current else {
            return nil
        }

        return .progressWouldMoveBackward(current: current, proposed: proposed)
    }

    private static func addingWithoutOverflow(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int.max : result.partialValue
    }

    private static func integralInt(_ value: Double?) -> Int? {
        guard let value = finite(value),
              value.rounded(.towardZero) == value,
              value >= Double(Int.min),
              value <= Double(Int.max) else {
            return nil
        }
        return Int(value)
    }

    private static func positiveIntegralInt(_ value: Double?) -> Int? {
        guard let value = integralInt(value), value > 0 else { return nil }
        return value
    }

    private static func nonNegativeIntegralInt(_ value: Double?) -> Int? {
        guard let value = integralInt(value), value >= 0 else { return nil }
        return value
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func nonNegativeFinite(_ value: Double?) -> Double? {
        guard let value = finite(value), value >= 0 else { return nil }
        return value
    }

    private static func positiveFinite(_ value: Double?) -> Double? {
        guard let value = finite(value), value > 0 else { return nil }
        return value
    }

    private static func normalizedLocator(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
