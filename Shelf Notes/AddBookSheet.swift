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
    case importBooks(initialQuery: String?)
    case scanner
    case inspiration

    var id: String {
        switch self {
        case .importBooks(let q):
            return "import:\(q ?? "")"
        case .scanner:
            return "scanner"
        case .inspiration:
            return "inspiration"
        }
    }

    var isImport: Bool {
        if case .importBooks = self { return true }
        return false
    }
}
