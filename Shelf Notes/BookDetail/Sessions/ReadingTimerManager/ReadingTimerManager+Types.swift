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

        /// The concrete reading attempt captured when the timer started.
        var readingAttemptID: UUID?

        /// Persisted source snapshot captured at timer start. It must not be
        /// derived again from a possibly changed book after relaunch.
        var readingMedium: ReadingMedium
        var readingProvider: ReadingProvider
        var progressUnit: ReadingProgressUnit
        var origin: ReadingSessionOrigin
        var expectedExternalReading: Bool
        var totalValue: Double?

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

        /// Timestamp when the app last moved away from active while this session
        /// was running. Persisted so external sessions can be evaluated after relaunch.
        var lastBackgroundedAt: Date?

        /// Display payload for the Reading Live Activity. Kept as a value snapshot so
        /// the widget extension never needs app-domain or SwiftData objects.
        var liveActivitySnapshot: ReadingSessionLiveActivitySnapshot?

        init(
            bookID: UUID,
            bookTitle: String,
            startedAt: Date,
            lastResumedAt: Date,
            accumulatedSeconds: Int,
            isPaused: Bool,
            pausedAt: Date?,
            sourceSnapshot: ReadingTimerSessionSourceSnapshot = .legacyPhysical,
            lastBackgroundedAt: Date? = nil,
            liveActivitySnapshot: ReadingSessionLiveActivitySnapshot? = nil
        ) {
            self.bookID = bookID
            self.bookTitle = bookTitle
            self.readingAttemptID = sourceSnapshot.readingAttemptID
            self.readingMedium = sourceSnapshot.readingMedium
            self.readingProvider = sourceSnapshot.readingProvider
            self.progressUnit = sourceSnapshot.progressUnit
            self.origin = sourceSnapshot.origin
            self.expectedExternalReading = sourceSnapshot.expectedExternalReading
            self.totalValue = sourceSnapshot.totalValue
            self.startedAt = startedAt
            self.lastResumedAt = lastResumedAt
            self.accumulatedSeconds = accumulatedSeconds
            self.isPaused = isPaused
            self.pausedAt = pausedAt
            self.lastBackgroundedAt = lastBackgroundedAt
            var normalizedSnapshot = liveActivitySnapshot
            normalizedSnapshot?.applySourceSnapshot(sourceSnapshot)
            self.liveActivitySnapshot = normalizedSnapshot
        }

        var sourceSnapshot: ReadingTimerSessionSourceSnapshot {
            ReadingTimerSessionSourceSnapshot(
                readingAttemptID: readingAttemptID,
                readingMedium: readingMedium,
                readingProvider: readingProvider,
                progressUnit: progressUnit,
                origin: origin,
                expectedExternalReading: expectedExternalReading,
                totalValue: totalValue
            )
        }

        mutating func applySourceSnapshot(_ snapshot: ReadingTimerSessionSourceSnapshot) {
            readingAttemptID = snapshot.readingAttemptID
            readingMedium = snapshot.readingMedium
            readingProvider = snapshot.readingProvider
            progressUnit = snapshot.progressUnit
            origin = snapshot.origin
            expectedExternalReading = snapshot.expectedExternalReading
            totalValue = snapshot.totalValue
            liveActivitySnapshot?.applySourceSnapshot(snapshot)
        }

        mutating func markBackgroundedIfNeeded(at date: Date) {
            if lastBackgroundedAt == nil {
                lastBackgroundedAt = date
            }
        }

        mutating func clearBackgrounded() {
            lastBackgroundedAt = nil
        }

        // Backward compatibility with earlier stored blobs.
        enum CodingKeys: String, CodingKey {
            case bookID, bookTitle, startedAt, lastResumedAt, accumulatedSeconds, isPaused, pausedAt, liveActivitySnapshot
            case readingAttemptID, readingMedium, readingProvider, progressUnit, origin, expectedExternalReading, totalValue, lastBackgroundedAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            self.bookID = try c.decode(UUID.self, forKey: .bookID)
            self.bookTitle = (try? c.decode(String.self, forKey: .bookTitle)) ?? "Buch"

            let legacySource = ReadingTimerSessionSourceSnapshot.legacyPhysical
            self.readingAttemptID = try? c.decode(UUID.self, forKey: .readingAttemptID)
            self.readingMedium = (try? c.decode(ReadingMedium.self, forKey: .readingMedium)) ?? legacySource.readingMedium
            self.readingProvider = (try? c.decode(ReadingProvider.self, forKey: .readingProvider)) ?? legacySource.readingProvider
            self.progressUnit = (try? c.decode(ReadingProgressUnit.self, forKey: .progressUnit)) ?? legacySource.progressUnit
            self.origin = (try? c.decode(ReadingSessionOrigin.self, forKey: .origin)) ?? legacySource.origin
            let inferredExternal = ReadingTimerSessionSourceSnapshot.defaultExpectedExternalReading(
                medium: readingMedium,
                provider: readingProvider,
                origin: origin
            )
            self.expectedExternalReading = (try? c.decode(Bool.self, forKey: .expectedExternalReading)) ?? inferredExternal
            let decodedTotalValue = try? c.decode(Double.self, forKey: .totalValue)
            self.totalValue = decodedTotalValue.flatMap { value in
                guard value.isFinite, value > 0 else { return nil }
                return value
            }

            let started = (try? c.decode(Date.self, forKey: .startedAt)) ?? Date()
            self.startedAt = started

            // If older blobs don't have these fields, default to running since startedAt.
            self.lastResumedAt = (try? c.decode(Date.self, forKey: .lastResumedAt)) ?? started
            self.accumulatedSeconds = (try? c.decode(Int.self, forKey: .accumulatedSeconds)) ?? 0
            self.isPaused = (try? c.decode(Bool.self, forKey: .isPaused)) ?? false
            self.pausedAt = try? c.decode(Date.self, forKey: .pausedAt)
            self.lastBackgroundedAt = try? c.decode(Date.self, forKey: .lastBackgroundedAt)
            let decodedSourceSnapshot = ReadingTimerSessionSourceSnapshot(
                readingAttemptID: readingAttemptID,
                readingMedium: readingMedium,
                readingProvider: readingProvider,
                progressUnit: progressUnit,
                origin: origin,
                expectedExternalReading: expectedExternalReading,
                totalValue: totalValue
            )
            var decodedLiveActivitySnapshot = try? c.decode(ReadingSessionLiveActivitySnapshot.self, forKey: .liveActivitySnapshot)
            decodedLiveActivitySnapshot?.applySourceSnapshot(decodedSourceSnapshot)
            self.liveActivitySnapshot = decodedLiveActivitySnapshot

            // Sanity: if paused but pausedAt missing, set it.
            if isPaused && pausedAt == nil {
                pausedAt = Date()
            }
            if isPaused {
                lastBackgroundedAt = nil
            }
        }
    }

    struct PendingCompletion: Identifiable, Equatable {
        let id: UUID
        var bookID: UUID
        var bookTitle: String

        /// Source snapshot captured when the timer started.
        var readingAttemptID: UUID?
        var readingMedium: ReadingMedium
        var readingProvider: ReadingProvider
        var progressUnit: ReadingProgressUnit
        var origin: ReadingSessionOrigin
        var expectedExternalReading: Bool
        var totalValue: Double?

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
            autoStopMinutes: Int?,
            sourceSnapshot: ReadingTimerSessionSourceSnapshot = .legacyPhysical
        ) {
            self.id = id
            self.bookID = bookID
            self.bookTitle = bookTitle
            self.readingAttemptID = sourceSnapshot.readingAttemptID
            self.readingMedium = sourceSnapshot.readingMedium
            self.readingProvider = sourceSnapshot.readingProvider
            self.progressUnit = sourceSnapshot.progressUnit
            self.origin = sourceSnapshot.origin
            self.expectedExternalReading = sourceSnapshot.expectedExternalReading
            self.totalValue = sourceSnapshot.totalValue
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = max(0, durationSeconds)
            self.wasAutoStopped = wasAutoStopped
            self.autoStopMinutes = autoStopMinutes
        }

        var sourceSnapshot: ReadingTimerSessionSourceSnapshot {
            ReadingTimerSessionSourceSnapshot(
                readingAttemptID: readingAttemptID,
                readingMedium: readingMedium,
                readingProvider: readingProvider,
                progressUnit: progressUnit,
                origin: origin,
                expectedExternalReading: expectedExternalReading,
                totalValue: totalValue
            )
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
