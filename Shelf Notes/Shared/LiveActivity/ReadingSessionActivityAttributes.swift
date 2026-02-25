//
//  ReadingSessionActivityAttributes.swift
//  Shelf Notes
//
//  Shared between the main app target and the Live Activity widget extension.
//

import Foundation
import ActivityKit

/// Live Activity attributes for a single active reading session.
struct ReadingSessionActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// True when the session is currently paused.
        var isPaused: Bool

        /// For the running state: an "effective" start date so `Text(date, style: .timer)`
        /// shows the correct elapsed duration without frequent updates.
        var effectiveStartDate: Date

        /// For the paused state: frozen duration.
        var pausedElapsedSeconds: Int
    }

    /// Stable identifier to ensure we can re-attach to an existing Activity after relaunch.
    var bookID: String

    /// Human readable title (trimmed + truncated in app before sending).
    var bookTitle: String
}

enum ReadingSessionDurationFormatter {
    static func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
