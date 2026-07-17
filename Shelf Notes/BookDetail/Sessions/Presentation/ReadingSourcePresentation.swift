//
//  ReadingSourcePresentation.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSourcePresentation: Equatable, Sendable {
    let title: String
    let systemImage: String
    let manualTrackingText: String?

    static func make(
        medium: ReadingMedium,
        provider: ReadingProvider,
        progressUnit: ReadingProgressUnit
    ) -> ReadingSourcePresentation {
        let selection = ReadingSourceSelection.resolved(
            medium: medium,
            provider: provider,
            progressUnit: progressUnit
        )

        let manualText: String?
        switch selection {
        case .physical:
            manualText = nil
        case .localFile:
            manualText = "Der integrierte Reader ist noch nicht verfügbar."
        case .appleBooks, .kindle, .googleBooks, .otherEbook:
            manualText = "Fortschritt manuell gepflegt"
        }

        return ReadingSourcePresentation(
            title: selection.title,
            systemImage: selection.systemImage,
            manualTrackingText: manualText
        )
    }
}
