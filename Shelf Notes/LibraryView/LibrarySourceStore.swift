//
//  LibrarySourceStore.swift
//  Shelf Notes
//
//  Keeps the source library index out of SwiftUI render helpers.
//

import Combine
import Foundation
import Observation

extension LibraryView {
    @MainActor final class LibrarySourceStore: ObservableObject {
        @Published private(set) var currentIndex: LibraryBooksIndex = .empty

        private var observedBooks: [Book] = []
        private var trackingGeneration = 0
        private(set) var completedIndexBuildCount = 0

        var sourceSignature: LibrarySourceSignature {
            currentIndex.librarySourceSignature
        }

        func refreshSourceAndTrack(books: [Book]) {
            observedBooks = books
            refreshObservedBooksAndTrack()
        }

        func refreshSnapshots(_ snapshots: [LibrarySourceSnapshot.BookSnapshot]) {
            let source = LibraryTrackedSource(
                snapshots: snapshots,
                orderedBookIDs: snapshots.map(\.id),
                booksByID: [:]
            )
            updateSource(source)
        }

        private func refreshObservedBooksAndTrack() {
            trackingGeneration += 1
            let generation = trackingGeneration

            let trackedSource = withObservationTracking {
                LibraryTrackedSource(books: observedBooks)
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.trackingGeneration == generation else { return }
                    self.refreshObservedBooksAndTrack()
                }
            }

            updateSource(trackedSource)
        }

        private func updateSource(_ trackedSource: LibraryTrackedSource) {
            guard currentIndex.sourceSignature != trackedSource.source.signature
                    || currentIndex.orderedBookIDs != trackedSource.orderedBookIDs else {
                return
            }

            currentIndex = trackedSource.makeIndex()
            completedIndexBuildCount += 1
        }
    }
}

private struct LibraryTrackedSource {
    let source: LibraryView.LibrarySourceSnapshot
    let orderedBookIDs: [UUID]
    let booksByID: [UUID: Book]

    @MainActor init(books: [Book]) {
        var indexedBooks: [UUID: Book] = [:]
        indexedBooks.reserveCapacity(books.count)

        var orderedIDs: [UUID] = []
        orderedIDs.reserveCapacity(books.count)

        var snapshots: [LibraryView.LibrarySourceSnapshot.BookSnapshot] = []
        snapshots.reserveCapacity(books.count)

        for book in books {
            indexedBooks[book.id] = book
            orderedIDs.append(book.id)
            snapshots.append(LibraryView.LibrarySourceSnapshot.BookSnapshot(book: book))
        }

        self.init(
            snapshots: snapshots,
            orderedBookIDs: orderedIDs,
            booksByID: indexedBooks
        )
    }

    init(
        snapshots: [LibraryView.LibrarySourceSnapshot.BookSnapshot],
        orderedBookIDs: [UUID],
        booksByID: [UUID: Book]
    ) {
        let signature = LibraryView.LibrarySourceSignature(bookSnapshots: snapshots)
        source = LibraryView.LibrarySourceSnapshot(
            signature: signature.rawValue,
            books: snapshots
        )
        self.orderedBookIDs = orderedBookIDs
        self.booksByID = booksByID
    }

    func makeIndex() -> LibraryView.LibraryBooksIndex {
        LibraryView.LibraryBooksIndex(
            source: source,
            orderedBookIDs: orderedBookIDs,
            booksByID: booksByID
        )
    }
}
