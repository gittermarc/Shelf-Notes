//
//  LocalFileFutureReaderIntegration.swift
//  Shelf Notes
//

import Foundation

nonisolated enum LocalFileFutureReaderIntegration {
    static let integration = ReadingIntegration(
        provider: .localFile,
        title: "Lokale EPUB/PDF",
        subtitle: "Reader-Integration ist vorbereitet, aber noch nicht verfügbar.",
        systemImage: "doc.richtext.fill",
        kind: .futureReader,
        capabilities: [],
        progressMode: .unavailable,
        baseAvailability: .comingSoon(detail: "Die lokale Reader-Schaltfläche bleibt deaktiviert, bis eine lokale Publikation und die Reader-Fähigkeit vorhanden sind."),
        manualSourceSelectable: false
    )
}