//
//  LibraryOverviewWidget.swift
//  ShelfNotesLiveActivity
//
//  Home Screen widget configuration for the Shelf Notes library overview.
//

import SwiftUI
import WidgetKit

struct LibraryOverviewWidget: Widget {
    static let kind = "LibraryOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LibraryOverviewTimelineProvider()) { entry in
            LibraryOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Bibliotheksüberblick")
        .description("Zeigt Bücher, Lesestatus, aktuelles Buch, Jahresziel und deine letzten Lesetage.")
        .supportedFamilies([
            .systemLarge,
            .systemExtraLarge
        ])
    }
}

#Preview("Bibliotheksüberblick", as: .systemLarge) {
    LibraryOverviewWidget()
} timeline: {
    LibraryOverviewWidgetEntry(
        date: Date(),
        snapshot: .placeholder(),
        isSnapshotUnavailable: false
    )
}
