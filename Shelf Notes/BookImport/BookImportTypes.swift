//
//  BookImportTypes.swift
//  Shelf Notes
//
//  Shared enums / UI types for the Google Books import flow.
//  Extracted from BookImportViewModel.swift to keep the view model lean.
//

import Foundation

enum BookImportLanguageOption: String, CaseIterable, Identifiable {
    case any
    case de
    case en
    case fr
    case es
    case it

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: return "Alle Sprachen"
        case .de: return "Deutsch"
        case .en: return "Englisch"
        case .fr: return "Französisch"
        case .es: return "Spanisch"
        case .it: return "Italienisch"
        }
    }

    var apiValue: String? {
        switch self {
        case .any: return nil
        default: return rawValue
        }
    }
}

enum BookImportSearchScope: String, CaseIterable, Identifiable {
    case any
    case title
    case author

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: return "Alles"
        case .title: return "Titel"
        case .author: return "Autor"
        }
    }
}

enum BookImportSortOption: String, CaseIterable, Identifiable {
    /// Keep the API's order ("relevance" from Google).
    case relevance
    /// Sort by published year (desc) locally and also request Google's "newest" order.
    case newest
    /// Prefer "high quality" hits (cover + isbn + metadata), locally.
    case quality
    case titleAZ

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relevance: return "Relevanz"
        case .newest: return "Neueste"
        case .quality: return "Qualität"
        case .titleAZ: return "Titel A–Z"
        }
    }

    var apiOrderBy: GoogleBooksOrderBy {
        switch self {
        case .newest: return .newest
        default: return .relevance
        }
    }
}

/// Where a search query came from.
///
/// - userTyped: the user entered the text in the search field (or scanned an ISBN).
/// - seed: the query originated from the Inspiration/"Magie" seed picker.
enum BookImportSearchOrigin: String, CaseIterable, Identifiable {
    case userTyped
    case seed

    var id: String { rawValue }
}
