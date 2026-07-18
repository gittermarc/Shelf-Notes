//
//  AppleBooksCompanionIntegration.swift
//  Shelf Notes
//

import Foundation

nonisolated enum AppleBooksCompanionIntegration {
    static let integration = ReadingIntegration(
        provider: .appleBooks,
        title: "Apple Books",
        subtitle: "Begleitmodus für externes Lesen in Apple Books.",
        systemImage: "books.vertical.fill",
        kind: .companion,
        capabilities: .companionWithShares,
        progressMode: .manual,
        baseAvailability: .companionAvailable(detail: "Timer und Live Activity laufen in Shelf Notes. Ein gespeicherter Apple-Books-Link kann geöffnet werden."),
        manualSourceSelectable: true
    )
}