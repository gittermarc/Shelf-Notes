//
//  LibraryDisplayState.swift
//  Shelf Notes
//
//  View-facing library display state resolved from the pure derived state.
//

import Foundation

extension LibraryView {
    struct LibraryDisplayState {
        let derivedState: LibraryDerivedState
        let displayedBooks: [Book]
        let alphaSections: [AlphaSection]
        let alphaLetters: [String]

        var token: LibraryDerivedInputToken {
            derivedState.token
        }

        var counts: LibraryStatusCounts {
            derivedState.counts
        }

        var displayedBookIDs: [UUID] {
            derivedState.displayedBookIDs
        }

        var isEmpty: Bool {
            displayedBooks.isEmpty
        }

        static var empty: LibraryDisplayState {
            LibraryDisplayState(
                derivedState: .empty,
                displayedBooks: [],
                alphaSections: [],
                alphaLetters: []
            )
        }

        @MainActor init(
            derivedState: LibraryDerivedState,
            index: LibraryBooksIndex
        ) {
            self.derivedState = derivedState
            displayedBooks = index.books(matching: derivedState.displayedBookIDs)
            alphaSections = index.alphaSections(for: derivedState.alphaSections)
            alphaLetters = derivedState.alphaLetters
        }

        init(
            derivedState: LibraryDerivedState,
            displayedBooks: [Book],
            alphaSections: [AlphaSection],
            alphaLetters: [String]
        ) {
            self.derivedState = derivedState
            self.displayedBooks = displayedBooks
            self.alphaSections = alphaSections
            self.alphaLetters = alphaLetters
        }
    }
}
