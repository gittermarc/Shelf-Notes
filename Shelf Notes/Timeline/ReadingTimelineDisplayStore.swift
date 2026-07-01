//
//  ReadingTimelineDisplayStore.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.07.26.
//

import Foundation
import Combine
import Observation

@MainActor
final class ReadingTimelineDisplayStore: ObservableObject {
    @Published private(set) var displayState: ReadingTimelineDisplayState = .empty
    @Published private(set) var hasBuiltTimeline = false
    @Published private(set) var isBuilding = false

    private var observedBooks: [Book] = []
    private var bookByID: [UUID: Book] = [:]
    private var lastAppliedSourceSignature: ReadingTimelineSourceSignature?
    private var trackingGeneration = 0
    private var buildGeneration = 0

    private(set) var completedBuildCount = 0

    var years: [Int] {
        displayState.years
    }

    func refreshSourceAndTrack(books: [Book]) async {
        observedBooks = books
        await refreshObservedBooksAndTrack()
    }

    func book(for id: UUID) -> Book? {
        bookByID[id]
    }

    func previewBooks(for ids: [UUID]) -> [Book] {
        ids.compactMap { bookByID[$0] }
    }

    func refreshSnapshots(_ snapshots: [ReadingTimelineBookSnapshot]) async {
        let source = ReadingTimelineTrackedSource(
            signature: ReadingTimelineSourceSignature(bookSnapshots: snapshots),
            bookSnapshots: snapshots,
            bookByID: [:]
        )
        await updateSource(source)
    }

    private func refreshObservedBooksAndTrack() async {
        trackingGeneration += 1
        let generation = trackingGeneration

        let trackedSource = withObservationTracking {
            ReadingTimelineTrackedSource(books: observedBooks)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.trackingGeneration == generation else { return }
                await self.refreshObservedBooksAndTrack()
            }
        }

        await updateSource(trackedSource)
    }

    private func updateSource(_ source: ReadingTimelineTrackedSource) async {
        bookByID = source.bookByID

        if hasBuiltTimeline, lastAppliedSourceSignature == source.signature {
            return
        }

        buildGeneration += 1
        let generation = buildGeneration
        let snapshots = source.bookSnapshots
        let signature = source.signature
        let calendar = Calendar.current

        isBuilding = true
        let nextDisplayState = await PerformanceSignposter.measureAsync("Timeline Build") {
            await Task.detached(priority: .userInitiated) {
                ReadingTimelineBuilder.build(bookSnapshots: snapshots, calendar: calendar)
            }.value
        }

        guard !Task.isCancelled else {
            if generation == buildGeneration {
                isBuilding = false
            }
            return
        }
        guard generation == buildGeneration else { return }

        displayState = nextDisplayState
        lastAppliedSourceSignature = signature
        hasBuiltTimeline = true
        isBuilding = false
        completedBuildCount += 1
    }
}

private struct ReadingTimelineTrackedSource {
    let signature: ReadingTimelineSourceSignature
    let bookSnapshots: [ReadingTimelineBookSnapshot]
    let bookByID: [UUID: Book]

    init(
        signature: ReadingTimelineSourceSignature,
        bookSnapshots: [ReadingTimelineBookSnapshot],
        bookByID: [UUID: Book]
    ) {
        self.signature = signature
        self.bookSnapshots = bookSnapshots
        self.bookByID = bookByID
    }

    init(books: [Book]) {
        let snapshots = ReadingTimelineBookSnapshot.snapshots(from: books)
        var bookByID: [UUID: Book] = [:]
        bookByID.reserveCapacity(books.count)
        for book in books {
            bookByID[book.id] = book
        }

        self.init(
            signature: ReadingTimelineSourceSignature(bookSnapshots: snapshots),
            bookSnapshots: snapshots,
            bookByID: bookByID
        )
    }
}
