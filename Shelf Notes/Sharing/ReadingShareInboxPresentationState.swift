//
//  ReadingShareInboxPresentationState.swift
//  Shelf Notes
//

import Foundation

struct ReadingShareInboxPresentationState: Equatable, Identifiable {
    var item: ReadingShareInboxItem
    var title: String
    var subtitle: String
    var providerTitle: String
    var previewText: String?
    var resolution: ReadingShareResolution

    var id: String { item.id }
}

enum ReadingShareInboxPresentationBuilder {
    static func make(
        item: ReadingShareInboxItem,
        resolution: ReadingShareResolution
    ) -> ReadingShareInboxPresentationState {
        let payload = item.payload
        return ReadingShareInboxPresentationState(
            item: item,
            title: payload.title ?? fallbackTitle(for: payload),
            subtitle: subtitle(for: payload),
            providerTitle: providerTitle(payload.provider),
            previewText: payload.text,
            resolution: resolution
        )
    }

    private static func fallbackTitle(for payload: ReadingSharePayload) -> String {
        switch payload.kind {
        case .bookLink:
            return "Geteilter Buchlink"
        case .text:
            return "Geteilter Text"
        case .textWithURL:
            return "Geteilter Text mit Link"
        }
    }

    private static func subtitle(for payload: ReadingSharePayload) -> String {
        switch payload.kind {
        case .bookLink:
            return payload.canonicalURL ?? "Buchlink"
        case .text:
            return "Notiz oder Textauswahl"
        case .textWithURL:
            return payload.canonicalURL ?? "Text mit Buchlink"
        }
    }

    private static func providerTitle(_ provider: ReadingProvider) -> String {
        switch provider {
        case .appleBooks:
            return "Apple Books"
        case .kindle:
            return "Kindle"
        case .googleBooks:
            return "Google Books"
        case .localFile:
            return "Lokale Datei"
        case .other:
            return "Anderer Anbieter"
        case .none:
            return "Keine Quelle"
        }
    }
}
