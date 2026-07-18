//
//  OtherEbookCompanionIntegration.swift
//  Shelf Notes
//

import Foundation

nonisolated enum OtherEbookCompanionIntegration {
    static let integration = ReadingIntegration(
        provider: .other,
        title: "Andere E-Book-App",
        subtitle: "Generischer Begleitmodus für dokumentierte HTTPS-Links.",
        systemImage: "apps.iphone",
        kind: .companion,
        capabilities: .companionWithShares,
        progressMode: .manual,
        baseAvailability: .companionAvailable(detail: "Timer und Live Activity laufen in Shelf Notes. Nur geprüfte HTTPS-Links werden geöffnet."),
        manualSourceSelectable: true
    )
}