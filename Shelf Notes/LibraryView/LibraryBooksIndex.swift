//
//  LibraryBooksIndex.swift
//  Shelf Notes
//
//  Lightweight index for resolving library display IDs without rebuilding
//  dictionaries in SwiftUI render helpers.
//

import Foundation

extension LibraryView {
    struct LibraryBooksIndex {
        let source: LibrarySourceSnapshot
        let orderedBookIDs: [UUID]
        private let booksByID: [UUID: Book]
        private let presentationsByID: [UUID: LibraryBookPresentation]

        static let empty = LibraryBooksIndex(
            source: .empty,
            orderedBookIDs: [],
            booksByID: [:],
            presentationsByID: [:]
        )

        init(
            source: LibrarySourceSnapshot,
            orderedBookIDs: [UUID],
            booksByID: [UUID: Book],
            presentationsByID: [UUID: LibraryBookPresentation]? = nil
        ) {
            self.source = source
            self.orderedBookIDs = orderedBookIDs
            self.booksByID = booksByID
            self.presentationsByID = presentationsByID ?? Self.makePresentationsByID(from: source.books)
        }

        @MainActor init(books: [Book]) {
            var indexedBooks: [UUID: Book] = [:]
            indexedBooks.reserveCapacity(books.count)

            var orderedIDs: [UUID] = []
            orderedIDs.reserveCapacity(books.count)

            var snapshots: [LibrarySourceSnapshot.BookSnapshot] = []
            snapshots.reserveCapacity(books.count)

            for book in books {
                indexedBooks[book.id] = book
                orderedIDs.append(book.id)
                snapshots.append(LibrarySourceSnapshot.BookSnapshot(book: book))
            }

            booksByID = indexedBooks
            orderedBookIDs = orderedIDs
            source = LibrarySourceSnapshot(
                signature: LibrarySourceSnapshot.computeSignature(snapshot: snapshots),
                books: snapshots
            )
            presentationsByID = Self.makePresentationsByID(from: snapshots)
        }

        var sourceSignature: Int {
            source.signature
        }

        var librarySourceSignature: LibrarySourceSignature {
            LibrarySourceSignature(rawValue: source.signature)
        }

        func token(input: LibraryDerivedInput) -> LibraryDerivedInputToken {
            LibraryDerivedInputToken(sourceSignature: sourceSignature, input: input)
        }

        func book(for id: UUID) -> Book? {
            booksByID[id]
        }

        func presentation(for id: UUID) -> LibraryBookPresentation? {
            presentationsByID[id]
        }

        func presentations(matching ids: [UUID]) -> [UUID: LibraryBookPresentation] {
            var result: [UUID: LibraryBookPresentation] = [:]
            result.reserveCapacity(ids.count)

            for id in ids {
                if let presentation = presentationsByID[id] {
                    result[id] = presentation
                }
            }

            return result
        }

        func books(matching ids: [UUID]) -> [Book] {
            ids.compactMap { booksByID[$0] }
        }

        func alphaSections(for descriptors: [AlphaSectionDescriptor]) -> [AlphaSection] {
            descriptors.map { descriptor in
                AlphaSection(
                    id: descriptor.id,
                    key: descriptor.key,
                    books: books(matching: descriptor.bookIDs)
                )
            }
        }

        private static func makePresentationsByID(
            from snapshots: [LibrarySourceSnapshot.BookSnapshot]
        ) -> [UUID: LibraryBookPresentation] {
            var result: [UUID: LibraryBookPresentation] = [:]
            result.reserveCapacity(snapshots.count)

            for snapshot in snapshots {
                result[snapshot.id] = LibraryBookPresentation(snapshot: snapshot)
            }

            return result
        }
    }
}
