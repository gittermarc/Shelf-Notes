//
//  ReadingTimerManager+Types.swift
//  Shelf Notes
//

import Foundation

extension ReadingTimerManager {

    // MARK: - Types

    struct ActiveState: Codable, Equatable {
        var bookID: UUID
        var bookTitle: String

        /// The moment the user first started the session (for display).
        var startedAt: Date

        /// The moment the timer was last resumed (only meaningful when not paused).
        var lastResumedAt: Date

        /// Accumulated seconds across previous run segments.
        var accumulatedSeconds: Int

        /// True when the session is currently paused.
        var isPaused: Bool

        /// Timestamp when the user paused (for display). Optional.
        var pausedAt: Date?

        init(
            bookID: UUID,
            bookTitle: String,
            startedAt: Date,
            lastResumedAt: Date,
            accumulatedSeconds: Int,
            isPaused: Bool,
            pausedAt: Date?
        ) {
            self.bookID = bookID
            self.bookTitle = bookTitle
            self.startedAt = startedAt
            self.lastResumedAt = lastResumedAt
            self.accumulatedSeconds = accumulatedSeconds
            self.isPaused = isPaused
            self.pausedAt = pausedAt
        }

        // Backward compatibility with earlier stored blobs (v1).
        enum CodingKeys: String, CodingKey {
            case bookID, bookTitle, startedAt, lastResumedAt, accumulatedSeconds, isPaused, pausedAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            self.bookID = try c.decode(UUID.self, forKey: .bookID)
            self.bookTitle = (try? c.decode(String.self, forKey: .bookTitle)) ?? "Buch"

            let started = (try? c.decode(Date.self, forKey: .startedAt)) ?? Date()
            self.startedAt = started

            // If older blobs don't have these fields, default to “running since startedAt”.
            self.lastResumedAt = (try? c.decode(Date.self, forKey: .lastResumedAt)) ?? started
            self.accumulatedSeconds = (try? c.decode(Int.self, forKey: .accumulatedSeconds)) ?? 0
            self.isPaused = (try? c.decode(Bool.self, forKey: .isPaused)) ?? false
            self.pausedAt = try? c.decode(Date.self, forKey: .pausedAt)

            // Sanity: if paused but pausedAt missing, set it.
            if isPaused && pausedAt == nil {
                pausedAt = Date()
            }
        }
    }

    struct PendingCompletion: Identifiable, Equatable {
        let id: UUID
        var bookID: UUID
        var bookTitle: String

        /// Display times (not used for duration calculation).
        var startedAt: Date
        var endedAt: Date

        /// Actual counted reading duration in seconds (supports pauses).
        var durationSeconds: Int

        var wasAutoStopped: Bool
        var autoStopMinutes: Int?

        init(
            id: UUID = UUID(),
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

    struct AutoStopSettings: Equatable {
        var enabled: Bool
        var minutes: Int
    }

    // MARK: - Keys (UserDefaults)

    enum Keys {
        static let activeBlob = "reading_timer_active_v1"
        static let autoStopEnabled = "session_autostop_enabled_v1"
        static let autoStopMinutes = "session_autostop_minutes_v1"
    }
}
