//
//  LibraryWidgetSnapshotRefreshNotification.swift
//  Shelf Notes
//
//  Lightweight app-internal signal that a SwiftData save happened and the library
//  widget snapshot can be refreshed from the RootView's active ModelContext.
//

import Foundation

nonisolated enum LibraryWidgetSnapshotRefreshNotification {
    static let name = Notification.Name("LibraryWidgetSnapshotRefreshNotification")
}
