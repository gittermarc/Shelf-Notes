//
//  ReadingProgressUpdate.swift
//  Shelf Notes
//

import Foundation

/// A value-only progress observation consumed by `ReadingProgressEngine`.
///
/// The stable identifier is used only as a deterministic tie-breaker when two
/// observations have the same timestamp.
nonisolated struct ReadingProgressUpdate: Equatable, Sendable {
    let stableIdentifier: String
    let occurredAt: Date
    let unit: ReadingProgressUnit
    let nativeValue: Double?
    let totalValue: Double?
    let normalizedProgress: Double?
    let locator: String?

    init(
        stableIdentifier: String,
        occurredAt: Date,
        unit: ReadingProgressUnit,
        nativeValue: Double? = nil,
        totalValue: Double? = nil,
        normalizedProgress: Double? = nil,
        locator: String? = nil
    ) {
        self.stableIdentifier = stableIdentifier
        self.occurredAt = occurredAt
        self.unit = unit
        self.nativeValue = nativeValue
        self.totalValue = totalValue
        self.normalizedProgress = normalizedProgress
        self.locator = locator
    }
}