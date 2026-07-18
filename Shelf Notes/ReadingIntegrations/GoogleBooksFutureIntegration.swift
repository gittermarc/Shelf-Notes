//
//  GoogleBooksFutureIntegration.swift
//  Shelf Notes
//

import Foundation

nonisolated enum GoogleBooksFutureIntegration {
    static let integration = ReadingIntegration(
        provider: .googleBooks,
        title: "Google Books",
        subtitle: "Noch keine Kontoverbindung und keine Fortschrittssynchronisierung.",
        systemImage: "book.pages.fill",
        kind: .futureSync,
        capabilities: [],
        progressMode: .manual,
        baseAvailability: .notConnected(detail: "Google Books bleibt in diesem PR eine manuelle Quelle. OAuth und Sync folgen erst in einer späteren Stufe."),
        manualSourceSelectable: true
    )
}