//
//  ReadingSessionLiveActivityCoordinator.swift
//  Shelf Notes
//
//  Mirrors the active ReadingTimerManager session into a Live Activity without
//  changing existing timer flows.
//

import Foundation
import ActivityKit

@MainActor
final class ReadingSessionLiveActivityCoordinator {

    // Keep a single activity instance. Shelf Notes enforces a single active timer session.
    @available(iOS 16.1, *)
    private var activity: Activity<ReadingSessionActivityAttributes>?

    func startOrUpdate(
        from active: ReadingTimerManager.ActiveState,
        autoStopMinutes: Int? = nil
    ) {
        guard #available(iOS 16.1, *) else { return }

        let now = Date()
        let (attributes, state) = makePayload(active: active, now: now)
        let content = makeActivityContent(from: state, now: now, autoStopMinutes: autoStopMinutes)

        Task { [weak self] in
            guard let self else { return }

            if let existing = self.activity, existing.attributes.bookID != attributes.bookID {
                await self.end(activity: existing, using: existing.content.state)
                self.activity = nil
            }

            self.activity = await self.resolveExistingActivity(bookID: attributes.bookID)

            if let existing = self.activity {
                await existing.update(content)
                LiveActivitySharedStore.removeOrphanedCoverFiles(keepingBookIDStrings: [attributes.bookID])
                return
            }

            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                LiveActivitySharedStore.removeOrphanedCoverFiles(keepingBookIDStrings: [attributes.bookID])
                return
            }

            do {
                let requested = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                self.activity = requested
                LiveActivitySharedStore.removeOrphanedCoverFiles(keepingBookIDStrings: [attributes.bookID])
            } catch {
                // Live Activities can be disabled by the user or fail for other reasons.
                // The reading timer must keep working even when ActivityKit is unavailable.
            }
        }
    }

    func endCurrentActivity() {
        guard #available(iOS 16.1, *) else { return }

        Task { [weak self] in
            guard let self else { return }

            if let activity = self.activity {
                await self.end(activity: activity, using: activity.content.state)
                self.activity = nil
            }
        }
    }

    // MARK: - Internals

    @available(iOS 16.1, *)
    private func end(
        activity: Activity<ReadingSessionActivityAttributes>,
        using state: ReadingSessionActivityAttributes.ContentState
    ) async {
        // End immediately so the lock screen doesn't show stale info once the sheet opens.
        await activity.end(makeActivityContent(from: state), dismissalPolicy: .immediate)
    }

    @available(iOS 16.1, *)
    private func resolveExistingActivity(bookID: String) async -> Activity<ReadingSessionActivityAttributes>? {
        var keeper: Activity<ReadingSessionActivityAttributes>?

        for existing in Activity<ReadingSessionActivityAttributes>.activities {
            if existing.attributes.bookID == bookID, keeper == nil {
                keeper = existing
            } else {
                await end(activity: existing, using: existing.content.state)
            }
        }

        return keeper
    }

    private func makeActivityContent(
        from state: ReadingSessionActivityAttributes.ContentState,
        now: Date = Date(),
        autoStopMinutes: Int? = nil
    ) -> ActivityContent<ReadingSessionActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: ReadingSessionLiveActivityLifecyclePolicy.staleDate(
                for: state,
                now: now,
                autoStopMinutes: autoStopMinutes
            )
        )
    }

    @available(iOS 16.2, *)
    nonisolated static func refreshExistingActivityFromSharedState(bookID: UUID, now: Date = Date()) async {
        let shared = LiveActivitySharedStore.userDefaults
        guard let active = ReadingTimerSharedCodec.decodeSupportedActive(from: shared.data(forKey: ReadingTimerSharedKeys.activeBlob)),
              active.bookID == bookID else {
            return
        }

        let state = ReadingSessionActivityAttributes.ContentState(active: active, now: now)
        let content = ActivityContent(
            state: state,
            staleDate: ReadingSessionLiveActivityLifecyclePolicy.staleDate(for: state, now: now)
        )
        let bookIDString = bookID.uuidString

        for activity in Activity<ReadingSessionActivityAttributes>.activities {
            if activity.attributes.bookID == bookIDString {
                await activity.update(content)
            }
        }
    }

    private func makePayload(active: ReadingTimerManager.ActiveState, now: Date) -> (
        ReadingSessionActivityAttributes,
        ReadingSessionActivityAttributes.ContentState
    ) {
        let elapsed = elapsedSeconds(now: now, active: active)
        let effectiveStartDate = now.addingTimeInterval(-Double(elapsed))
        let snapshot = active.liveActivitySnapshot ?? ReadingSessionLiveActivitySnapshot.fallback(
            bookID: active.bookID,
            bookTitle: active.bookTitle,
            isPaused: active.isPaused
        )

        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)

        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: active.isPaused,
            effectiveStartDate: effectiveStartDate,
            pausedElapsedSeconds: elapsed,
            snapshot: snapshot,
            contentUpdatedAt: now
        )

        return (attributes, state)
    }

    private func elapsedSeconds(now: Date, active: ReadingTimerManager.ActiveState) -> Int {
        let base = max(0, active.accumulatedSeconds)
        if active.isPaused {
            return base
        }
        let segment = max(0, Int(now.timeIntervalSince(active.lastResumedAt).rounded()))
        return max(0, base + segment)
    }
}
