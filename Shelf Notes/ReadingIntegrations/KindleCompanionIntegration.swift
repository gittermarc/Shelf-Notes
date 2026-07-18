//
//  KindleCompanionIntegration.swift
//  Shelf Notes
//

import Foundation

nonisolated enum KindleCompanionIntegration {
    static let integration = ReadingIntegration(
        provider: .kindle,
        title: "Kindle",
        subtitle: "Begleitmodus für externes Lesen in Kindle.",
        systemImage: "rectangle.portrait.fill",
        kind: .companion,
        capabilities: .companionWithShares,
        progressMode: .manual,
        baseAvailability: .companionAvailable(detail: "Timer und Live Activity laufen in Shelf Notes. Ein gespeicherter Amazon- oder Kindle-Weblink kann geöffnet werden."),
        manualSourceSelectable: true
    )
}