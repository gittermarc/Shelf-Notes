//
//  LibraryOverviewTimelineProvider.swift
//  ShelfNotesLiveActivity
//
//  Lightweight timeline provider for the Library Overview widget.
//

import Foundation
import WidgetKit

struct LibraryOverviewWidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: LibraryOverviewWidgetSnapshot
    var isSnapshotUnavailable: Bool

    var presentation: LibraryOverviewWidgetPresentation {
        LibraryOverviewWidgetPresentation(
            snapshot: snapshot,
            isSnapshotUnavailable: isSnapshotUnavailable,
            now: date
        )
    }
}

struct LibraryOverviewTimelineProvider: TimelineProvider {
    private let store: LibraryOverviewWidgetStore

    init(store: LibraryOverviewWidgetStore = LibraryOverviewWidgetStore()) {
        self.store = store
    }

    func placeholder(in context: Context) -> LibraryOverviewWidgetEntry {
        LibraryOverviewWidgetEntry(
            date: Date(),
            snapshot: .placeholder(),
            isSnapshotUnavailable: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LibraryOverviewWidgetEntry) -> Void) {
        completion(makeEntry(date: Date(), usePlaceholderForPreview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LibraryOverviewWidgetEntry>) -> Void) {
        let date = Date()
        let entry = makeEntry(date: date, usePlaceholderForPreview: context.isPreview)
        let nextRefresh = date.addingTimeInterval(60 * 30)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry(
        date: Date,
        usePlaceholderForPreview: Bool
    ) -> LibraryOverviewWidgetEntry {
        if usePlaceholderForPreview {
            return LibraryOverviewWidgetEntry(
                date: date,
                snapshot: .placeholder(generatedAt: date),
                isSnapshotUnavailable: false
            )
        }

        switch store.loadState() {
        case .loaded(let snapshot):
            return LibraryOverviewWidgetEntry(
                date: date,
                snapshot: snapshot,
                isSnapshotUnavailable: false
            )

        case .unavailable:
            return LibraryOverviewWidgetEntry(
                date: date,
                snapshot: .empty(generatedAt: date),
                isSnapshotUnavailable: true
            )
        }
    }
}
