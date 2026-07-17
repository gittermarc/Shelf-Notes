//
//  ReadingProgressEngine.swift
//  Shelf Notes
//

import Foundation

/// Pure, format-neutral progress calculation for a single reading attempt.
nonisolated enum ReadingProgressEngine {
    static func snapshot(for input: ReadingProgressAttemptSnapshot) -> ReadingProgressSnapshot {
        switch input.unit {
        case .pages:
            return pageSnapshot(for: input)
        case .percentage:
            return percentageSnapshot(for: input)
        case .locator:
            return locatorSnapshot(for: input)
        case .none:
            return .unknown(unit: .none, isCompleted: input.status == .finished)
        }
    }

    private static func pageSnapshot(
        for input: ReadingProgressAttemptSnapshot
    ) -> ReadingProgressSnapshot {
        let totalPages = reliablePageTotal(
            pageCountSnapshot: input.pageCountSnapshot,
            totalValueSnapshot: input.totalValueSnapshot,
            updates: input.updates
        )
        let pagesRead = positivePageSum(input.sessionPageValues)
        let isCompleted = input.status == .finished

        if isCompleted {
            return ReadingProgressSnapshot(
                unit: .pages,
                nativeValue: pagesRead > 0 ? Double(pagesRead) : nil,
                totalValue: totalPages.map(Double.init),
                pagesRead: pagesRead > 0 ? pagesRead : nil,
                remainingPages: 0,
                normalizedProgress: 1,
                locator: nil,
                isCompleted: true
            )
        }

        guard pagesRead > 0 else {
            return ReadingProgressSnapshot(
                unit: .pages,
                nativeValue: nil,
                totalValue: totalPages.map(Double.init),
                pagesRead: nil,
                remainingPages: totalPages,
                normalizedProgress: nil,
                locator: nil,
                isCompleted: false
            )
        }

        let normalizedProgress: Double?
        let remainingPages: Int?
        if let totalPages {
            normalizedProgress = clampedFraction(
                numerator: Double(pagesRead),
                denominator: Double(totalPages)
            )
            remainingPages = max(0, totalPages - pagesRead)
        } else {
            normalizedProgress = nil
            remainingPages = nil
        }

        return ReadingProgressSnapshot(
            unit: .pages,
            nativeValue: Double(pagesRead),
            totalValue: totalPages.map(Double.init),
            pagesRead: pagesRead,
            remainingPages: remainingPages,
            normalizedProgress: normalizedProgress,
            locator: nil,
            isCompleted: false
        )
    }

    private static func percentageSnapshot(
        for input: ReadingProgressAttemptSnapshot
    ) -> ReadingProgressSnapshot {
        let selected = latestUpdate(
            in: input.updates,
            unit: .percentage,
            isValid: hasValidPercentageValue
        )
        let isCompleted = input.status == .finished

        guard let selected else {
            return .unknown(unit: .percentage, isCompleted: isCompleted)
        }

        let total = reliablePositiveFinite(selected.totalValue)
            ?? reliablePositiveFinite(input.totalValueSnapshot)
        let normalizationTotal = total ?? 100
        let normalized = isCompleted
            ? 1
            : normalizedPercentage(update: selected, fallbackTotal: normalizationTotal)

        return ReadingProgressSnapshot(
            unit: .percentage,
            nativeValue: finiteNonNegative(selected.nativeValue),
            totalValue: total,
            pagesRead: nil,
            remainingPages: nil,
            normalizedProgress: normalized,
            locator: normalizedLocator(selected.locator),
            isCompleted: isCompleted
        )
    }

    private static func locatorSnapshot(
        for input: ReadingProgressAttemptSnapshot
    ) -> ReadingProgressSnapshot {
        let selected = latestUpdate(
            in: input.updates,
            unit: .locator
        ) { update in
            normalizedLocator(update.locator) != nil
        }
        let isCompleted = input.status == .finished

        guard let selected else {
            return .unknown(unit: .locator, isCompleted: isCompleted)
        }

        let normalizedProgress: Double?
        if isCompleted {
            normalizedProgress = 1
        } else {
            normalizedProgress = finite(selected.normalizedProgress).map(clampToUnitInterval)
        }

        return ReadingProgressSnapshot(
            unit: .locator,
            nativeValue: finite(selected.nativeValue),
            totalValue: reliablePositiveFinite(selected.totalValue),
            pagesRead: nil,
            remainingPages: nil,
            normalizedProgress: normalizedProgress,
            locator: normalizedLocator(selected.locator),
            isCompleted: isCompleted
        )
    }

    private static func latestUpdate(
        in updates: [ReadingProgressUpdate],
        unit: ReadingProgressUnit,
        isValid: (ReadingProgressUpdate) -> Bool
    ) -> ReadingProgressUpdate? {
        updates
            .filter { $0.unit == unit && isValid($0) }
            .max { left, right in
                if left.occurredAt != right.occurredAt {
                    return left.occurredAt < right.occurredAt
                }
                return left.stableIdentifier < right.stableIdentifier
            }
    }

    private static func hasValidPercentageValue(_ update: ReadingProgressUpdate) -> Bool {
        if finite(update.normalizedProgress) != nil {
            return true
        }
        return finiteNonNegative(update.nativeValue) != nil
    }

    private static func normalizedPercentage(
        update: ReadingProgressUpdate,
        fallbackTotal: Double
    ) -> Double? {
        if let normalized = finite(update.normalizedProgress) {
            return clampToUnitInterval(normalized)
        }

        guard let native = finiteNonNegative(update.nativeValue) else {
            return nil
        }

        return clampedFraction(numerator: native, denominator: fallbackTotal)
    }

    private static func reliablePageTotal(
        pageCountSnapshot: Int?,
        totalValueSnapshot: Double?,
        updates: [ReadingProgressUpdate]
    ) -> Int? {
        if let pageCountSnapshot, pageCountSnapshot > 0 {
            return pageCountSnapshot
        }

        if let total = integralPositiveInt(totalValueSnapshot) {
            return total
        }

        let latestTotal = latestUpdate(
            in: updates,
            unit: .pages
        ) { update in
            integralPositiveInt(update.totalValue) != nil
        }

        return integralPositiveInt(latestTotal?.totalValue)
    }

    private static func positivePageSum(_ values: [Int]) -> Int {
        var result = 0

        for value in values where value > 0 {
            let addition = result.addingReportingOverflow(value)
            result = addition.overflow ? Int.max : addition.partialValue
            if result == Int.max {
                break
            }
        }

        return result
    }

    private static func integralPositiveInt(_ value: Double?) -> Int? {
        guard let value = reliablePositiveFinite(value) else { return nil }
        guard value.rounded(.towardZero) == value else { return nil }
        guard value <= Double(Int.max) else { return nil }
        return Int(value)
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func finiteNonNegative(_ value: Double?) -> Double? {
        guard let value = finite(value), value >= 0 else { return nil }
        return value
    }

    private static func reliablePositiveFinite(_ value: Double?) -> Double? {
        guard let value = finite(value), value > 0 else { return nil }
        return value
    }

    private static func clampedFraction(
        numerator: Double,
        denominator: Double
    ) -> Double? {
        guard numerator.isFinite, denominator.isFinite, denominator > 0 else {
            return nil
        }
        return clampToUnitInterval(numerator / denominator)
    }

    private static func clampToUnitInterval(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func normalizedLocator(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }
}