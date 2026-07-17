//
//  ReadingSessionMetricMapper.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSessionMetricInput: Equatable, Sendable {
    let startedAt: Date
    let durationSeconds: Int
    let pagesRead: Int?
    let nativeValue: Double?
    let normalizedProgress: Double?
    let locator: String?
    let progressUnitRawValue: String
    let originRawValue: String

    init(
        startedAt: Date,
        durationSeconds: Int,
        pagesRead: Int?,
        nativeValue: Double? = nil,
        normalizedProgress: Double? = nil,
        locator: String? = nil,
        progressUnitRawValue: String = ReadingProgressUnit.pages.rawValue,
        originRawValue: String = ReadingSessionOrigin.legacy.rawValue
    ) {
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = pagesRead.flatMap { $0 > 0 ? $0 : nil }
        self.nativeValue = nativeValue.flatMap { $0.isFinite ? $0 : nil }
        self.normalizedProgress = normalizedProgress.flatMap { value in
            guard value.isFinite else { return nil }
            return min(1, max(0, value))
        }
        self.locator = locator?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        self.progressUnitRawValue = progressUnitRawValue
        self.originRawValue = originRawValue
    }

    var progressUnit: ReadingProgressUnit {
        ReadingProgressUnit.fromPersisted(progressUnitRawValue)
    }

    var origin: ReadingSessionOrigin {
        ReadingSessionOrigin.fromPersisted(originRawValue)
    }
}

nonisolated enum ReadingSessionMetricMapper {
    static func contribution(
        from input: ReadingSessionMetricInput
    ) -> ReadingMetricContribution {
        let eligibility = ReadingMetricEligibility.session(
            progressUnit: input.progressUnit,
            origin: input.origin
        )
        let pages = eligibility.contributesPages ? (input.pagesRead ?? 0) : 0
        let duration = eligibility.contributesReadingTime ? input.durationSeconds : 0
        let pageBasedDuration = eligibility.contributesPages ? duration : 0

        return ReadingMetricContribution(
            source: .session,
            progressUnit: input.progressUnit,
            sessionCount: eligibility.contributesSession ? 1 : 0,
            durationSeconds: duration,
            pageBasedDurationSeconds: pageBasedDuration,
            readingDay: eligibility.contributesReadingDay && duration > 0 ? input.startedAt : nil,
            pagesRead: pages,
            hasMeasuredProgress: measuredProgressExists(input: input, pages: pages),
            normalizedProgress: input.normalizedProgress,
            locator: input.locator,
            isCompletion: false
        )
    }

    private static func measuredProgressExists(
        input: ReadingSessionMetricInput,
        pages: Int
    ) -> Bool {
        switch input.progressUnit {
        case .pages:
            return pages > 0
        case .percentage:
            return input.normalizedProgress != nil || input.nativeValue != nil
        case .locator:
            return input.locator != nil || input.normalizedProgress != nil
        case .none:
            return false
        }
    }
}

private nonisolated extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
