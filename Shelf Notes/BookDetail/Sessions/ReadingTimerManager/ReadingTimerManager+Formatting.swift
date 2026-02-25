//
//  ReadingTimerManager+Formatting.swift
//  Shelf Notes
//

import Foundation

extension ReadingTimerManager {

    // MARK: - Formatting

    static func formatDuration(_ seconds: Int) -> String {
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
