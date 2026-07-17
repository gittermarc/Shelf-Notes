//
//  ReadingProgressSnapshot.swift
//  Shelf Notes
//

import Foundation

/// Format-neutral progress result for one reading attempt.
nonisolated struct ReadingProgressSnapshot: Equatable, Sendable {
    let unit: ReadingProgressUnit
    let nativeValue: Double?
    let totalValue: Double?
    let pagesRead: Int?
    let remainingPages: Int?
    let normalizedProgress: Double?
    let locator: String?
    let isCompleted: Bool

    var hasMeasurableProgress: Bool {
        isCompleted
            || nativeValue != nil
            || pagesRead != nil
            || normalizedProgress != nil
            || locator != nil
    }

    static func unknown(
        unit: ReadingProgressUnit,
        totalValue: Double? = nil,
        isCompleted: Bool = false
    ) -> ReadingProgressSnapshot {
        ReadingProgressSnapshot(
            unit: unit,
            nativeValue: nil,
            totalValue: totalValue,
            pagesRead: nil,
            remainingPages: nil,
            normalizedProgress: isCompleted ? 1 : nil,
            locator: nil,
            isCompleted: isCompleted
        )
    }
}