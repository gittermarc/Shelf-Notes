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
        let presentationsByBookID: [UUID: LibraryBookPresentation]
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
                presentationsByBookID: [:],
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
            presentationsByBookID = index.presentations(matching: derivedState.displayedBookIDs)
            alphaSections = index.alphaSections(for: derivedState.alphaSections)
            alphaLetters = derivedState.alphaLetters
        }

        init(
            derivedState: LibraryDerivedState,
            displayedBooks: [Book],
            presentationsByBookID: [UUID: LibraryBookPresentation],
            alphaSections: [AlphaSection],
            alphaLetters: [String]
        ) {
            self.derivedState = derivedState
            self.displayedBooks = displayedBooks
            self.presentationsByBookID = presentationsByBookID
            self.alphaSections = alphaSections
            self.alphaLetters = alphaLetters
        }

        func presentation(for book: Book) -> LibraryBookPresentation? {
            presentationsByBookID[book.id]
        }
    }
}
