//
//  AddBookSheet.swift
//  Shelf Notes
//
//  Created by Marc Fechner + ChatGPT on 31.01.26.
//

import Foundation

/// Centralizes all sheet routing for `AddBookView`.
/// Using a single `sheet(item:)` avoids the classic Bool-zoo.
enum AddBookSheet: Identifiable, Equatable {
    case importBooks(initialQuery: String?, origin: BookImportSearchOrigin)
    case scanner
    case inspiration
    case manualAdd

    var id: String {
        switch self {
        case .importBooks(let q, let origin):
            return "import:\(origin.rawValue):\(q ?? "")"
        case .scanner:
            return "scanner"
        case .inspiration:
            return "inspiration"
        case .manualAdd:
            return "manualAdd"
        }
    }

    var isImport: Bool {
        if case .importBooks = self { return true }
        return false
    }
}
