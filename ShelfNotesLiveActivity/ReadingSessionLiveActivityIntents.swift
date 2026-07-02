//
//  ReadingSessionLiveActivityIntents.swift
//  ShelfNotesLiveActivity
//
//  Lock screen controls for the reading session Live Activity.
//

import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct ReadingSessionTogglePauseIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Pause/Resume Reading Session"
    static var description = IntentDescription("Toggles pause/resume for the active reading timer session.")

    @Parameter(title: "Book ID")
    var bookID: String

    init() {}

    init(bookID: String) {
        self.bookID = bookID
    }

    func perform() async throws -> some IntentResult {
        let now = Date()

        guard let uuid = UUID(uuidString: bookID) else {
            return .result()
        }

        let shared = LiveActivitySharedStore.userDefaults
        guard let data = shared.data(forKey: ReadingTimerSharedKeys.activeBlob) else {
            return .result()
        }

        do {
            var blob = try JSONDecoder().decode(ReadingTimerActiveBlob.self, from: data)
            guard blob.bookID == uuid else {
                return .result()
            }

            if blob.isPaused {
                blob.resume(now: now)
            } else {
                blob.pause(now: now)
            }

            let out = try JSONEncoder().encode(blob)
            shared.set(out, forKey: ReadingTimerSharedKeys.activeBlob)

            await updateLiveActivity(bookIDString: bookID, active: blob, now: now)
        } catch {
            // Non-fatal.
        }

        return .result()
    }

    private func updateLiveActivity(bookIDString: String, active: ReadingTimerActiveBlob, now: Date) async {
        let state = ReadingSessionActivityAttributes.ContentState(active: active, now: now)
        let content = ActivityContent(state: state, staleDate: nil)

        for activity in Activity<ReadingSessionActivityAttributes>.activities {
            if activity.attributes.bookID == bookIDString {
                await activity.update(content)
            }
        }
    }
}

@available(iOS 17.0, *)
struct ReadingSessionStopIntent: LiveActivityIntent {

    static var title: LocalizedStringResource = "Stop Reading Session"
    static var description = IntentDescription("Stops the active reading timer session.")

    @Parameter(title: "Book ID")
    var bookID: String

    init() {}

    init(bookID: String) {
        self.bookID = bookID
    }

    func perform() async throws -> some IntentResult {
        let now = Date()
        guard let uuid = UUID(uuidString: bookID) else {
            let state = ReadingSessionActivityAttributes.ContentState(
                isPaused: true,
                effectiveStartDate: now,
                pausedElapsedSeconds: 0,
                contentUpdatedAt: now
            )
            await endLiveActivity(bookIDString: bookID, state: state)
            return .result()
        }

        let shared = LiveActivitySharedStore.userDefaults
        var endingState = ReadingSessionActivityAttributes.ContentState(
            isPaused: true,
            effectiveStartDate: now,
            pausedElapsedSeconds: 0,
            contentUpdatedAt: now
        )

        if let data = shared.data(forKey: ReadingTimerSharedKeys.activeBlob),
           let active = try? JSONDecoder().decode(ReadingTimerActiveBlob.self, from: data),
           active.bookID == uuid {

            let end: Date
            if active.isPaused {
                end = active.pausedAt ?? now
            } else {
                end = now
            }

            let duration = active.totalElapsedSeconds(now: end)
            endingState = ReadingSessionActivityAttributes.ContentState(
                isPaused: true,
                effectiveStartDate: end.addingTimeInterval(-Double(duration)),
                pausedElapsedSeconds: duration,
                snapshot: active.liveActivitySnapshot,
                contentUpdatedAt: now
            )
            let pending = ReadingTimerPendingCompletionBlob(
                id: UUID(),
                bookID: active.bookID,
                bookTitle: active.bookTitle,
                startedAt: active.startedAt,
                endedAt: end,
                durationSeconds: duration,
                wasAutoStopped: false,
                autoStopMinutes: nil
            )

            if let pendingData = try? JSONEncoder().encode(pending) {
                shared.set(pendingData, forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
            }

            shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
        }

        await endLiveActivity(bookIDString: bookID, state: endingState)
        return .result()
    }

    private func endLiveActivity(
        bookIDString: String,
        state: ReadingSessionActivityAttributes.ContentState
    ) async {
        let content = ActivityContent(state: state, staleDate: nil)

        for activity in Activity<ReadingSessionActivityAttributes>.activities {
            if activity.attributes.bookID == bookIDString {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }
}
