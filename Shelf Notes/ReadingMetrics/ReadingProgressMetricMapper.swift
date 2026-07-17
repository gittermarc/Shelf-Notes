//
//  ReadingProgressMetricMapper.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingProgressMetricInput: Equatable, Sendable {
    let progressUnitRawValue: String
    let originRawValue: String
    let nativeValue: Double?
    let normalizedProgress: Double?
    let locator: String?
    let isCompleted: Bool

    init(
        progressUnitRawValue: String,
        originRawValue: String = ReadingSessionOrigin.legacy.rawValue,
        nativeValue: Double? = nil,
        normalizedProgress: Double? = nil,
        locator: String? = nil,
        isCompleted: Bool = false
    ) {
        self.progressUnitRawValue = progressUnitRawValue
        self.originRawValue = originRawValue
        self.nativeValue = nativeValue
        self.normalizedProgress = normalizedProgress
        self.locator = locator
        self.isCompleted = isCompleted
    }

    var progressUnit: ReadingProgressUnit {
        ReadingProgressUnit.fromPersisted(progressUnitRawValue)
    }

    var origin: ReadingSessionOrigin {
        ReadingSessionOrigin.fromPersisted(originRawValue)
    }
}

nonisolated enum ReadingProgressMetricMapper {
    static func contribution(
        from input: ReadingProgressMetricInput,
        source: ReadingMetricDataSource = .progressEvent
    ) -> ReadingMetricContribution {
        let eligibility: ReadingMetricEligibility
        switch source {
        case .session:
            eligibility = .session(progressUnit: input.progressUnit, origin: input.origin)
        case .progressEvent:
            eligibility = .progressEvent(progressUnit: input.progressUnit, origin: input.origin)
        case .completion:
            eligibility = .completion(progressUnit: input.progressUnit)
        }

        let normalized = normalizedFraction(input.normalizedProgress)
        let locator = normalizedLocator(input.locator)
        let native = finite(input.nativeValue)
        let hasProgress: Bool
        if input.isCompleted {
            hasProgress = true
        } else {
            switch input.progressUnit {
            case .pages:
                hasProgress = native.map { $0 > 0 } ?? false
            case .percentage:
                hasProgress = normalized != nil || native != nil
            case .locator:
                hasProgress = locator != nil || normalized != nil
            case .none:
                hasProgress = false
            }
        }

        return ReadingMetricContribution(
            source: source,
            progressUnit: input.progressUnit,
            sessionCount: 0,
            durationSeconds: 0,
            pageBasedDurationSeconds: 0,
            readingDay: nil,
            pagesRead: 0,
            hasMeasuredProgress: eligibility.contributesBookProgress && hasProgress,
            normalizedProgress: normalized,
            locator: locator,
            isCompletion: eligibility.contributesCompletion && input.isCompleted
        )
    }

    static func contribution(
        from snapshot: ReadingProgressSnapshot,
        origin: ReadingSessionOrigin = .legacy,
        source: ReadingMetricDataSource = .progressEvent
    ) -> ReadingMetricContribution {
        contribution(
            from: ReadingProgressMetricInput(
                progressUnitRawValue: snapshot.unit.rawValue,
                originRawValue: origin.rawValue,
                nativeValue: snapshot.nativeValue,
                normalizedProgress: snapshot.normalizedProgress,
                locator: snapshot.locator,
                isCompleted: snapshot.isCompleted
            ),
            source: source
        )
    }

    static func pageCountContribution(
        pageCount: Int?,
        progressUnit: ReadingProgressUnit
    ) -> Int? {
        guard ReadingMetricEligibility.completion(progressUnit: progressUnit).contributesPages,
              let pageCount,
              pageCount > 0 else {
            return nil
        }
        return pageCount
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func normalizedFraction(_ value: Double?) -> Double? {
        guard let value = finite(value) else { return nil }
        return min(1, max(0, value))
    }

    private static func normalizedLocator(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }
}
