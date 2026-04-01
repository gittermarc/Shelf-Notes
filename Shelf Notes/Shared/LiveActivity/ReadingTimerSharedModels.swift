//
//  ReadingTimerSharedModels.swift
//  Shelf Notes
//
//  Codable wire models used to share the timer session state between
//  the main app and the Live Activity extension.
//

import Foundation

nonisolated enum ReadingTimerSharedKeys {
    /// Stored in App Group UserDefaults.
    static let activeBlob: String = "reading_timer_active_v1"

    /// Stored in App Group UserDefaults.
    static let pendingCompletionBlob: String = "reading_timer_pending_completion_v1"
}

/// Shared, Codable representation of the current active timer session.
///
/// This is intentionally duplicated (instead of referencing `ReadingTimerManager.ActiveState`)
/// so the widget extension can decode it without importing the app module.
nonisolated struct ReadingTimerActiveBlob: Codable, Equatable {
    var bookID: UUID
    var bookTitle: String
    var startedAt: Date
    var lastResumedAt: Date
    var accumulatedSeconds: Int
    var isPaused: Bool
    var pausedAt: Date?

    func totalElapsedSeconds(now: Date) -> Int {
        let base = max(0, accumulatedSeconds)
        if isPaused {
            return base
        }
        let segment = max(0, Int(now.timeIntervalSince(lastResumedAt).rounded()))
        return max(0, base + segment)
    }

    mutating func pause(now: Date) {
        guard !isPaused else { return }
        let segment = max(0, Int(now.timeIntervalSince(lastResumedAt).rounded()))
        accumulatedSeconds = max(0, accumulatedSeconds + segment)
        isPaused = true
        pausedAt = now
    }

    mutating func resume(now: Date) {
        guard isPaused else { return }
        isPaused = false
        pausedAt = nil
        lastResumedAt = now
    }
}

/// Shared, Codable representation of a timer session completion that still needs user input.
nonisolated struct ReadingTimerPendingCompletionBlob: Codable, Equatable {
    var id: UUID
    var bookID: UUID
    var bookTitle: String
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var wasAutoStopped: Bool
    var autoStopMinutes: Int?

    init(
        id: UUID,
        bookID: UUID,
        bookTitle: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        wasAutoStopped: Bool,
        autoStopMinutes: Int?
    ) {
        self.id = id
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.wasAutoStopped = wasAutoStopped
        self.autoStopMinutes = autoStopMinutes
    }
}
