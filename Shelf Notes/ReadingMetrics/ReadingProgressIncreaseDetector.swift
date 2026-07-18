//
//  ReadingProgressIncreaseDetector.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingProgressComparableObservation: Equatable, Sendable {
    let unit: ReadingProgressUnit
    let nativeValue: Double?
    let totalValue: Double?
    let normalizedProgress: Double?
    let locator: String?

    init(
        unit: ReadingProgressUnit,
        nativeValue: Double? = nil,
        totalValue: Double? = nil,
        normalizedProgress: Double? = nil,
        locator: String? = nil
    ) {
        self.unit = unit
        self.nativeValue = Self.finite(nativeValue)
        self.totalValue = Self.positiveFinite(totalValue)
        self.normalizedProgress = Self.normalized(normalizedProgress)
        self.locator = locator?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    var comparableValue: Double? {
        switch unit {
        case .pages:
            return nativeValue.flatMap { $0 >= 0 ? $0 : nil }
        case .percentage:
            if let normalizedProgress {
                return normalizedProgress
            }
            guard let nativeValue, nativeValue >= 0 else { return nil }
            let total = totalValue ?? 100
            return min(1, max(0, nativeValue / total))
        case .locator:
            return normalizedProgress
        case .none:
            return nil
        }
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func positiveFinite(_ value: Double?) -> Double? {
        guard let value = finite(value), value > 0 else { return nil }
        return value
    }

    private static func normalized(_ value: Double?) -> Double? {
        guard let value = finite(value) else { return nil }
        return min(1, max(0, value))
    }
}

nonisolated enum ReadingProgressIncreaseDetector {
    private static let tolerance = 0.000_000_1

    static func hasIncrease(
        from previous: ReadingProgressComparableObservation?,
        to current: ReadingProgressComparableObservation
    ) -> Bool {
        guard current.unit != .none,
              let currentValue = current.comparableValue else {
            return false
        }

        guard let previous,
              previous.unit == current.unit,
              let previousValue = previous.comparableValue else {
            return currentValue > tolerance
        }

        return currentValue > previousValue + tolerance
    }

    static func sessionHasIncrease(
        unit: ReadingProgressUnit,
        pagesRead: Int?,
        startValue: Double?,
        endValue: Double?,
        startNormalizedProgress: Double?,
        endNormalizedProgress: Double?,
        startLocator: String?,
        endLocator: String?
    ) -> Bool {
        if unit == .pages {
            return (pagesRead ?? 0) > 0
        }

        let previous = ReadingProgressComparableObservation(
            unit: unit,
            nativeValue: startValue,
            normalizedProgress: startNormalizedProgress,
            locator: startLocator
        )
        let current = ReadingProgressComparableObservation(
            unit: unit,
            nativeValue: endValue,
            normalizedProgress: endNormalizedProgress,
            locator: endLocator
        )
        return hasIncrease(from: previous, to: current)
    }
}

private nonisolated extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
