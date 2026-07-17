//
//  ReadingMetricEligibility.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingMetricDataSource: String, Hashable, Sendable {
    case session
    case progressEvent
    case completion
}

nonisolated struct ReadingMetricEligibility: Equatable, Sendable {
    let contributesSession: Bool
    let contributesReadingTime: Bool
    let contributesReadingDay: Bool
    let contributesPages: Bool
    let contributesBookProgress: Bool
    let contributesCompletion: Bool

    static func session(
        progressUnit: ReadingProgressUnit,
        origin: ReadingSessionOrigin
    ) -> ReadingMetricEligibility {
        let isReadingActivity = origin != .providerImport
        return ReadingMetricEligibility(
            contributesSession: isReadingActivity,
            contributesReadingTime: isReadingActivity,
            contributesReadingDay: isReadingActivity,
            contributesPages: isReadingActivity && progressUnit == .pages,
            contributesBookProgress: progressUnit != .none,
            contributesCompletion: false
        )
    }

    static func progressEvent(
        progressUnit: ReadingProgressUnit,
        origin: ReadingSessionOrigin
    ) -> ReadingMetricEligibility {
        ReadingMetricEligibility(
            contributesSession: false,
            contributesReadingTime: false,
            contributesReadingDay: false,
            contributesPages: false,
            contributesBookProgress: progressUnit != .none,
            contributesCompletion: true
        )
    }

    static func completion(
        progressUnit: ReadingProgressUnit
    ) -> ReadingMetricEligibility {
        ReadingMetricEligibility(
            contributesSession: false,
            contributesReadingTime: false,
            contributesReadingDay: false,
            contributesPages: progressUnit == .pages,
            contributesBookProgress: true,
            contributesCompletion: true
        )
    }
}
