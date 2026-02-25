//
//  LiveActivityCoverLoader.swift
//  ShelfNotesLiveActivity
//
//  Loads the small JPEG cover thumbnail from the App Group container.
//

import Foundation
import UIKit

enum LiveActivityCoverLoader {
    static func load(bookIDString: String) -> UIImage? {
        guard let url = LiveActivitySharedStore.coverFileURL(bookIDString: bookIDString) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
