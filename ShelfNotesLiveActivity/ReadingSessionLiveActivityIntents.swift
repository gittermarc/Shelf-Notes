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
        let activeData = shared.data(forKey: ReadingTimerSharedKeys.activeBlob)
        guard let blob = ReadingTimerSharedCodec.decodeActive(from: activeData) else {
            if activeData != nil {
                shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            }
            return .result()
        }

        guard blob.hasSupportedSchemaVersion else {
            shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            return .result()
        }

        guard blob.bookID == uuid else {
            return .result()
        }

        var updatedBlob = blob
        if updatedBlob.isPaused {
            updatedBlob.resume(now: now)
        } else {
            updatedBlob.pause(now: now)
        }

        if let out = ReadingTimerSharedCodec.encodeActive(updatedBlob) {
            shared.set(out, forKey: ReadingTimerSharedKeys.activeBlob)
            await updateLiveActivity(bookIDString: bookID, active: updatedBlob, now: now)
        }

        return .result()
    }

    private func updateLiveActivity(bookIDString: String, active: ReadingTimerActiveBlob, now: Date) async {
        let state = ReadingSessionActivityAttributes.ContentState(active: active, now: now)
        let content = ActivityContent(
            state: state,
            staleDate: ReadingSessionLiveActivityLifecyclePolicy.staleDate(for: state, now: now)
        )

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
            await endLiveActivity(bookIDString: bookID, state: state, now: now)
            return .result()
        }

        let shared = LiveActivitySharedStore.userDefaults
        var endingState = ReadingSessionActivityAttributes.ContentState(
            isPaused: true,
            effectiveStartDate: now,
            pausedElapsedSeconds: 0,
            contentUpdatedAt: now
        )

        let activeData = shared.data(forKey: ReadingTimerSharedKeys.activeBlob)
        guard let active = ReadingTimerSharedCodec.decodeActive(from: activeData) else {
            if activeData != nil {
                shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            }
            await endLiveActivity(bookIDString: bookID, state: endingState, now: now)
            return .result()
        }

        guard active.hasSupportedSchemaVersion else {
            shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            await endLiveActivity(bookIDString: bookID, state: endingState, now: now)
            return .result()
        }

        guard active.bookID == uuid else {
            await endLiveActivity(bookIDString: bookID, state: endingState, now: now)
            return .result()
        }

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

        if let pendingData = ReadingTimerSharedCodec.encodePendingCompletion(pending) {
            shared.set(pendingData, forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
        }

        shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
        LiveActivitySharedStore.removeCoverFile(bookIDString: bookID)

        await endLiveActivity(bookIDString: bookID, state: endingState, now: now)
        return .result()
    }

    private func endLiveActivity(
        bookIDString: String,
        state: ReadingSessionActivityAttributes.ContentState,
        now: Date
    ) async {
        let content = ActivityContent(
            state: state,
            staleDate: ReadingSessionLiveActivityLifecyclePolicy.staleDate(for: state, now: now)
        )

        for activity in Activity<ReadingSessionActivityAttributes>.activities {
            if activity.attributes.bookID == bookIDString {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }
}
