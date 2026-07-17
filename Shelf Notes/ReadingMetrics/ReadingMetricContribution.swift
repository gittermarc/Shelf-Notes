//
//  ReadingMetricContribution.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingMetricContribution: Equatable, Sendable {
    let source: ReadingMetricDataSource
    let progressUnit: ReadingProgressUnit
    let sessionCount: Int
    let durationSeconds: Int
    let pageBasedDurationSeconds: Int
    let readingDay: Date?
    let pagesRead: Int
    let hasMeasuredProgress: Bool
    let normalizedProgress: Double?
    let locator: String?
    let isCompletion: Bool

    static func empty(
        source: ReadingMetricDataSource,
        progressUnit: ReadingProgressUnit
    ) -> ReadingMetricContribution {
        ReadingMetricContribution(
            source: source,
            progressUnit: progressUnit,
            sessionCount: 0,
            durationSeconds: 0,
            pageBasedDurationSeconds: 0,
            readingDay: nil,
            pagesRead: 0,
            hasMeasuredProgress: false,
            normalizedProgress: nil,
            locator: nil,
            isCompletion: false
        )
    }
}
