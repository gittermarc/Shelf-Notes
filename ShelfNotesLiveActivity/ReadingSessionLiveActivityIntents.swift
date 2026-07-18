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

        switch LiveActivitySharedStore.togglePauseForActiveSession(bookID: uuid, now: now) {
        case .updated(let active):
            await updateLiveActivity(bookIDString: bookID, active: active, now: now)
        case .failure:
            break
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

        switch LiveActivitySharedStore.stopActiveSession(bookID: uuid, now: now) {
        case .stopped(let active, let pending):
            let state = ReadingSessionActivityAttributes.ContentState(
                isPaused: true,
                effectiveStartDate: pending.endedAt.addingTimeInterval(-Double(pending.durationSeconds)),
                pausedElapsedSeconds: pending.durationSeconds,
                snapshot: active.liveActivitySnapshot,
                source: active.sourceSnapshot,
                contentUpdatedAt: now
            )
            await endLiveActivity(bookIDString: bookID, state: state, now: now)
        case .failure:
            let state = ReadingSessionActivityAttributes.ContentState(
                isPaused: true,
                effectiveStartDate: now,
                pausedElapsedSeconds: 0,
                contentUpdatedAt: now
            )
            await endLiveActivity(bookIDString: bookID, state: state, now: now)
        }

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
