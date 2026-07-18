//
//  ReadingIntegrationPresentation.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingIntegrationPresentationState: Identifiable, Equatable, Sendable {
    var provider: ReadingProvider
    var title: String
    var subtitle: String
    var systemImage: String
    var availabilityTitle: String
    var availabilityDetail: String
    var progressModeTitle: String
    var progressModeDetail: String
    var capabilityTitles: [String]
    var showsConnectedBadge: Bool

    var id: ReadingProvider { provider }
}

nonisolated enum ReadingIntegrationPresentationBuilder {
    static func make(
        integration: ReadingIntegration,
        environment: ReadingIntegrationEnvironment = ReadingIntegrationEnvironment()
    ) -> ReadingIntegrationPresentationState {
        let availability = ReadingIntegrationAvailabilityResolver.availability(
            for: integration,
            environment: environment
        )
        let capabilityTitles = integration.capabilities.orderedItems.map(\.title)

        return ReadingIntegrationPresentationState(
            provider: integration.provider,
            title: integration.title,
            subtitle: integration.subtitle,
            systemImage: integration.systemImage,
            availabilityTitle: availability.title,
            availabilityDetail: availability.detail,
            progressModeTitle: integration.progressMode.title,
            progressModeDetail: integration.progressMode.detail,
            capabilityTitles: capabilityTitles,
            showsConnectedBadge: availability.isConnectedPresentation
        )
    }

    static func makeAll(
        registry: ReadingIntegrationRegistry = .default,
        environment: ReadingIntegrationEnvironment = ReadingIntegrationEnvironment()
    ) -> [ReadingIntegrationPresentationState] {
        registry.integrations.map { integration in
            make(integration: integration, environment: environment)
        }
    }
}

nonisolated struct ReadingAttemptSourcePresentationState: Equatable, Sendable {
    var title: String
    var detail: String
    var systemImage: String
    var canChange: Bool
    var changeHint: String?
}

nonisolated enum ReadingAttemptSourcePresentationBuilder {
    static func make(
        hasActiveAttempt: Bool,
        medium: ReadingMedium,
        provider: ReadingProvider,
        progressUnit: ReadingProgressUnit,
        canChangeSource: Bool,
        isTimerActiveForBook: Bool,
        registry: ReadingIntegrationRegistry = .default
    ) -> ReadingAttemptSourcePresentationState {
        let sourcePresentation = ReadingSourcePresentation.make(
            medium: medium,
            provider: provider,
            progressUnit: progressUnit
        )
        let selection = ReadingSourceSelection.resolved(
            medium: medium,
            provider: provider,
            progressUnit: progressUnit
        )
        let integration = registry.integration(for: provider)
        let title = hasActiveAttempt ? sourcePresentation.title : "Lesequelle wählen"
        let detail: String

        if hasActiveAttempt {
            if let manualTrackingText = sourcePresentation.manualTrackingText {
                detail = manualTrackingText + " · " + progressUnitDetail(progressUnit)
            } else {
                detail = progressUnitDetail(progressUnit)
            }
        } else {
            detail = "Beim Starten einer Session legst du Quelle und Fortschrittseinheit fest."
        }

        let canChange = hasActiveAttempt && canChangeSource && !isTimerActiveForBook
        let changeHint: String?
        if canChange {
            changeHint = nil
        } else if isTimerActiveForBook {
            changeHint = "Während der Timer läuft nicht änderbar"
        } else if hasActiveAttempt && !canChangeSource {
            changeHint = "Nach Sessions oder Fortschritt gesperrt"
        } else {
            changeHint = nil
        }

        return ReadingAttemptSourcePresentationState(
            title: title,
            detail: detail,
            systemImage: integration?.systemImage ?? selection.systemImage,
            canChange: canChange,
            changeHint: changeHint
        )
    }

    private static func progressUnitDetail(_ unit: ReadingProgressUnit) -> String {
        switch unit {
        case .pages:
            return "Seitenfortschritt"
        case .percentage:
            return "Prozentfortschritt"
        case .locator:
            return "Locator-Fortschritt"
        case .none:
            return "Ohne Fortschrittswert"
        }
    }
}