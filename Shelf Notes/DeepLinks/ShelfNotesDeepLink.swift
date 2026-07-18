//
//  ShelfNotesDeepLink.swift
//  Shelf Notes
//
//  Central app-side parser for non-Live-Activity Shelf Notes deep links.
//

import Foundation

nonisolated enum ShelfNotesDeepLinkDestination: Equatable, Sendable {
    case library
    case book(UUID)
    case progress
    case shareInbox
}

nonisolated struct ShelfNotesDeepLink: Equatable, Sendable {
    let destination: ShelfNotesDeepLinkDestination

    static let scheme = "shelfnotes"
    static let libraryHost = "library"
    static let bookHost = "book"
    static let progressHost = "progress"
    static let shareInboxHost = "share-inbox"

    static func route(from url: URL) -> ShelfNotesDeepLink? {
        guard url.scheme == scheme else { return nil }

        let host = normalizedHost(from: url)
        switch host {
        case libraryHost:
            return ShelfNotesDeepLink(destination: .library)

        case progressHost:
            return ShelfNotesDeepLink(destination: .progress)

        case shareInboxHost:
            return ShelfNotesDeepLink(destination: .shareInbox)

        case bookHost:
            guard let bookID = bookID(from: url) else {
                return ShelfNotesDeepLink(destination: .library)
            }
            return ShelfNotesDeepLink(destination: .book(bookID))

        default:
            return nil
        }
    }

    private static func normalizedHost(from url: URL) -> String {
        if let host = url.host?.lowercased(), !host.isEmpty {
            return host
        }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.lowercased()
    }

    private static func bookID(from url: URL) -> UUID? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        let idString = items.first(where: { item in
            item.name == "id" || item.name == "bookID"
        })?.value
        return idString.flatMap(UUID.init(uuidString:))
    }
}
