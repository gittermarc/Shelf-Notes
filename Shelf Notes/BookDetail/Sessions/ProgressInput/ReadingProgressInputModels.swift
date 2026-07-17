//
//  ReadingProgressInputModels.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingProgressInputConfiguration: Equatable, Sendable {
    let unit: ReadingProgressUnit
    let currentProgress: ReadingProgressSnapshot
    let remainingPages: Int?
    let allowsPageOverflow: Bool
    let sourceTitle: String
    let isManuallyTracked: Bool

    init(
        unit: ReadingProgressUnit,
        currentProgress: ReadingProgressSnapshot,
        remainingPages: Int? = nil,
        allowsPageOverflow: Bool = false,
        sourceTitle: String,
        isManuallyTracked: Bool
    ) {
        self.unit = unit
        self.currentProgress = currentProgress
        self.remainingPages = remainingPages
        self.allowsPageOverflow = allowsPageOverflow
        self.sourceTitle = sourceTitle
        self.isManuallyTracked = isManuallyTracked
    }
}

nonisolated struct ReadingProgressInputState: Equatable, Sendable {
    var pagesText: String = ""
    var percentageText: String = ""
    var locatorText: String = ""
    var locatorPercentageText: String = ""
    var marksBookFinished: Bool = false
    var confirmsCorrection: Bool = false
}

nonisolated struct ReadingProgressInputSubmission: Equatable, Sendable {
    let progressUpdate: ReadingProgressUpdate?
    let mutationMode: ReadingProgressMutationMode

    var pagesDelta: Int? {
        guard progressUpdate?.unit == .pages,
              progressUpdate?.semantics == .delta,
              let value = progressUpdate?.nativeValue,
              value.isFinite,
              value > 0,
              value.rounded(.towardZero) == value,
              value <= Double(Int.max) else {
            return nil
        }
        return Int(value)
    }
}

nonisolated enum ReadingProgressInputError: Error, Equatable, Sendable {
    case invalidPages
    case invalidPercentage
    case missingLocator
    case correctionConfirmationRequired(current: Int, proposed: Int)
    case mutation(ReadingProgressMutationValidationError)

    var message: String {
        switch self {
        case .invalidPages:
            return "Bitte eine positive ganze Seitenzahl eingeben oder das Feld leer lassen."
        case .invalidPercentage:
            return "Bitte einen Prozentwert zwischen 0 und 100 eingeben oder das Feld leer lassen."
        case .missingLocator:
            return "Bitte eine Leseposition oder Kapitelinformation eingeben."
        case .correctionConfirmationRequired(let current, let proposed):
            return "Der neue Stand von \(proposed) % liegt unter den bisherigen \(current) %. Bestätige die bewusste Korrektur."
        case .mutation(let error):
            return error.message
        }
    }
}
