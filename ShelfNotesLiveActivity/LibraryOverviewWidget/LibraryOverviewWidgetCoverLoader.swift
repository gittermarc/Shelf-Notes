//
//  LibraryOverviewWidgetCoverLoader.swift
//  ShelfNotesLiveActivity
//
//  Loads small local JPEG covers exported by the main app into the App Group.
//

import Foundation
import UIKit

enum LibraryOverviewWidgetCoverLoader {
    static let directoryName = "LibraryWidgetCovers"
    static let filePrefix = "widget_cover_"
    static let fileExtension = "jpg"

    static func load(bookID: UUID) -> UIImage? {
        guard let containerURL = LiveActivitySharedStore.appGroupContainerURL else { return nil }
        let directoryURL = containerURL.appendingPathComponent(directoryName, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent(fileName(bookID: bookID), isDirectory: false)
        return UIImage(contentsOfFile: fileURL.path)
    }

    private static func fileName(bookID: UUID) -> String {
        "\(filePrefix)\(bookID.uuidString).\(fileExtension)"
    }
}
