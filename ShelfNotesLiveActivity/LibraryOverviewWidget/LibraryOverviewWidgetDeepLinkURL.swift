//
//  LibraryOverviewWidgetDeepLinkURL.swift
//  ShelfNotesLiveActivity
//
//  URL factory for tappable Library Overview widget areas.
//

import Foundation

enum LibraryOverviewWidgetDeepLinkURL {
    static var library: URL? {
        url(host: "library")
    }

    static var progress: URL? {
        url(host: "progress")
    }

    static func book(id: UUID) -> URL? {
        var components = baseComponents(host: "book")
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
        return components.url
    }

    private static func url(host: String) -> URL? {
        baseComponents(host: host).url
    }

    private static func baseComponents(host: String) -> URLComponents {
        var components = URLComponents()
        components.scheme = "shelfnotes"
        components.host = host
        return components
    }
}
