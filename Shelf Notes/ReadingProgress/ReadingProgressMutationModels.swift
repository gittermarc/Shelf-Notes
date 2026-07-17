//
//  ReadingProgressMutationModels.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingProgressMutationMode: Equatable, Sendable {
    case standard
    case correction
}

nonisolated enum ReadingProgressMutationValidationError: Error, Equatable, Sendable {
    case noRemainingPages(total: Int)
    case pagesExceedRemaining(remaining: Int, total: Int)
    case invalidPageDelta
    case invalidAbsolutePageValue
    case invalidPercentageValue
    case missingLocator
    case progressUnitMismatch(expected: ReadingProgressUnit, actual: ReadingProgressUnit)
    case progressWouldMoveBackward(current: Double, proposed: Double)

    var message: String {
        switch self {
        case .noRemainingPages(let total):
            return "Dieses Buch hat bereits alle \(total) Seiten erreicht – du kannst keine weiteren Seiten loggen."
        case .pagesExceedRemaining(let remaining, let total):
            return "Zu viele Seiten: Es sind nur noch \(remaining) von \(total) Seiten übrig."
        case .invalidPageDelta:
            return "Die gelesenen Seiten müssen eine positive ganze Zahl sein."
        case .invalidAbsolutePageValue:
            return "Der absolute Seitenstand muss eine nicht-negative ganze Zahl sein."
        case .invalidPercentageValue:
            return "Der Prozentstand ist ungültig und konnte nicht zuverlässig normalisiert werden."
        case .missingLocator:
            return "Für einen Locator-Fortschritt wird ein nicht-leerer Locator benötigt."
        case .progressUnitMismatch(let expected, let actual):
            return "Die Fortschrittseinheit \(actual.rawValue) passt nicht zum aktuellen Lesedurchgang mit \(expected.rawValue)."
        case .progressWouldMoveBackward(let current, let proposed):
            let currentPercent = Int((current * 100).rounded())
            let proposedPercent = Int((proposed * 100).rounded())
            return "Der neue Fortschritt von \(proposedPercent) % liegt unter dem aktuellen Stand von \(currentPercent) %. Nutze dafür ausdrücklich den Korrekturmodus."
        }
    }
}

nonisolated struct ReadingProgressMutationPlan: Equatable, Sendable {
    let unit: ReadingProgressUnit
    let update: ReadingProgressUpdate?
    let pagesDelta: Int?
    let startValue: Double?
    let endValue: Double?
    let startNormalizedProgress: Double?
    let endNormalizedProgress: Double?
    let startLocator: String?
    let endLocator: String?
    let eventNativeValue: Double?
    let eventTotalValue: Double?
    let eventNormalizedProgress: Double?
    let eventLocator: String?
    let didReachCompletion: Bool
    let shouldPersistEvent: Bool

    static func noUpdate(unit: ReadingProgressUnit) -> ReadingProgressMutationPlan {
        ReadingProgressMutationPlan(
            unit: unit,
            update: nil,
            pagesDelta: nil,
            startValue: nil,
            endValue: nil,
            startNormalizedProgress: nil,
            endNormalizedProgress: nil,
            startLocator: nil,
            endLocator: nil,
            eventNativeValue: nil,
            eventTotalValue: nil,
            eventNormalizedProgress: nil,
            eventLocator: nil,
            didReachCompletion: false,
            shouldPersistEvent: false
        )
    }
}
