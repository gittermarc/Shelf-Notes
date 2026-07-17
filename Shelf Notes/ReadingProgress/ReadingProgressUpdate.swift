//
//  ReadingProgressUpdate.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingProgressUpdateSemantics: Equatable, Sendable {
    case absolute
    case delta
    case completion
}

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
    let semantics: ReadingProgressUpdateSemantics

    init(
        stableIdentifier: String,
        occurredAt: Date,
        unit: ReadingProgressUnit,
        nativeValue: Double? = nil,
        totalValue: Double? = nil,
        normalizedProgress: Double? = nil,
        locator: String? = nil,
        semantics: ReadingProgressUpdateSemantics = .absolute
    ) {
        self.stableIdentifier = stableIdentifier
        self.occurredAt = occurredAt
        self.unit = unit
        self.nativeValue = nativeValue
        self.totalValue = totalValue
        self.normalizedProgress = normalizedProgress
        self.locator = locator
        self.semantics = semantics
    }

    static func pageDelta(
        _ pages: Int,
        occurredAt: Date,
        stableIdentifier: String = "session:pages"
    ) -> ReadingProgressUpdate {
        ReadingProgressUpdate(
            stableIdentifier: stableIdentifier,
            occurredAt: occurredAt,
            unit: .pages,
            nativeValue: Double(pages),
            semantics: .delta
        )
    }

    static func percentage(
        nativeValue: Double? = nil,
        totalValue: Double? = nil,
        normalizedProgress: Double? = nil,
        occurredAt: Date,
        stableIdentifier: String = "session:percentage"
    ) -> ReadingProgressUpdate {
        ReadingProgressUpdate(
            stableIdentifier: stableIdentifier,
            occurredAt: occurredAt,
            unit: .percentage,
            nativeValue: nativeValue,
            totalValue: totalValue,
            normalizedProgress: normalizedProgress
        )
    }

    static func locator(
        _ locator: String,
        nativeValue: Double? = nil,
        totalValue: Double? = nil,
        normalizedProgress: Double? = nil,
        occurredAt: Date,
        stableIdentifier: String = "session:locator"
    ) -> ReadingProgressUpdate {
        ReadingProgressUpdate(
            stableIdentifier: stableIdentifier,
            occurredAt: occurredAt,
            unit: .locator,
            nativeValue: nativeValue,
            totalValue: totalValue,
            normalizedProgress: normalizedProgress,
            locator: locator
        )
    }

    static func completed(
        occurredAt: Date,
        unit: ReadingProgressUnit = .none,
        stableIdentifier: String = "session:completed"
    ) -> ReadingProgressUpdate {
        ReadingProgressUpdate(
            stableIdentifier: stableIdentifier,
            occurredAt: occurredAt,
            unit: unit,
            normalizedProgress: 1,
            semantics: .completion
        )
    }
}
