//
//  ReadingSourceSelection.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingSourceSelection: String, CaseIterable, Identifiable, Equatable, Sendable {
    case physical
    case appleBooks
    case kindle
    case googleBooks
    case otherEbook
    case localFile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .physical:
            return "Physisches Buch"
        case .appleBooks:
            return "Apple Books"
        case .kindle:
            return "Kindle"
        case .googleBooks:
            return "Google Books"
        case .otherEbook:
            return "Andere E-Book-App"
        case .localFile:
            return "EPUB oder PDF in Shelf Notes"
        }
    }

    var subtitle: String {
        switch self {
        case .physical:
            return "Gelesene Seiten manuell erfassen"
        case .appleBooks, .kindle, .googleBooks, .otherEbook:
            return "Lesestand manuell in Prozent erfassen"
        case .localFile:
            return "Der integrierte Reader folgt in einem späteren Update"
        }
    }

    var systemImage: String {
        switch self {
        case .physical:
            return "book.closed.fill"
        case .appleBooks:
            return "books.vertical.fill"
        case .kindle:
            return "rectangle.portrait.fill"
        case .googleBooks:
            return "book.pages.fill"
        case .otherEbook:
            return "apps.iphone"
        case .localFile:
            return "doc.richtext.fill"
        }
    }

    var isAvailable: Bool {
        self != .localFile
    }

    var isManuallyTracked: Bool {
        self != .localFile
    }

    var medium: ReadingMedium {
        self == .physical ? .physical : .ebook
    }

    var provider: ReadingProvider {
        switch self {
        case .physical:
            return .none
        case .appleBooks:
            return .appleBooks
        case .kindle:
            return .kindle
        case .googleBooks:
            return .googleBooks
        case .otherEbook:
            return .other
        case .localFile:
            return .localFile
        }
    }

    var progressUnit: ReadingProgressUnit {
        switch self {
        case .physical:
            return .pages
        case .appleBooks, .kindle, .googleBooks, .otherEbook:
            return .percentage
        case .localFile:
            return .locator
        }
    }

    static func resolved(
        medium: ReadingMedium,
        provider: ReadingProvider,
        progressUnit: ReadingProgressUnit
    ) -> ReadingSourceSelection {
        if medium == .physical {
            return .physical
        }

        switch provider {
        case .appleBooks:
            return .appleBooks
        case .kindle:
            return .kindle
        case .googleBooks:
            return .googleBooks
        case .localFile:
            return .localFile
        case .other, .none:
            return .otherEbook
        }
    }
}
