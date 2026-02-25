//
//  ReadingSessionLiveActivityCoordinator.swift
//  Shelf Notes
//
//  Phase 1 (display-only): mirrors the active ReadingTimerManager session into a Live Activity
//  without changing any existing UI flows.
//

import Foundation
import ActivityKit

@MainActor
final class ReadingSessionLiveActivityCoordinator {

    // Keep a single activity instance. Shelf Notes enforces a single active timer session.
    @available(iOS 16.1, *)
    private var activity: Activity<ReadingSessionActivityAttributes>?

    func startOrUpdate(from active: ReadingTimerManager.ActiveState) {
        guard #available(iOS 16.1, *) else { return }

        let now = Date()
        let (attributes, state) = makePayload(active: active, now: now)

        Task { [weak self] in
            guard let self else { return }

            if let existing = self.activity {
                // If attributes mismatch, end + recreate (should be rare; app prevents it).
                if existing.attributes.bookID != attributes.bookID {
                    await self.endCurrentActivityInternal(using: existing.content.state)
                    self.activity = nil
                }
            }

            if self.activity == nil {
                self.activity = self.findExistingActivity(bookID: attributes.bookID)
            }

            if let existing = self.activity {
                await existing.update(using: state)
                return
            }

            do {
                let requested = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
                self.activity = requested
            } catch {
                // Live Activities can be disabled by the user or fail for other reasons.
                // We intentionally ignore errors to keep the timer flow unchanged.
            }
        }
    }

    func endCurrentActivity() {
        guard #available(iOS 16.1, *) else { return }

        Task { [weak self] in
            guard let self else { return }

            if let activity = self.activity {
                await self.endCurrentActivityInternal(using: activity.content.state)
                self.activity = nil
            }
        }
    }

    // MARK: - Internals

    @available(iOS 16.1, *)
    private func endCurrentActivityInternal(using state: ReadingSessionActivityAttributes.ContentState) async {
        // End immediately so the lock screen doesn't show stale info once the sheet opens.
        await activity?.end(using: state, dismissalPolicy: .immediate)
    }

    @available(iOS 16.1, *)
    private func findExistingActivity(bookID: String) -> Activity<ReadingSessionActivityAttributes>? {
        for a in Activity<ReadingSessionActivityAttributes>.activities {
            if a.attributes.bookID == bookID {
                return a
            }
        }
        return nil
    }

    private func makePayload(active: ReadingTimerManager.ActiveState, now: Date) -> (
        ReadingSessionActivityAttributes,
        ReadingSessionActivityAttributes.ContentState
    ) {
        let elapsed = elapsedSeconds(now: now, active: active)
        let effectiveStartDate = now.addingTimeInterval(-Double(elapsed))

        let attributes = ReadingSessionActivityAttributes(
            bookID: active.bookID.uuidString,
            bookTitle: sanitizeTitle(active.bookTitle)
        )

        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: active.isPaused,
            effectiveStartDate: effectiveStartDate,
            pausedElapsedSeconds: elapsed
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

    private func sanitizeTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Buch" : trimmed

        // Keep lock screen layout predictable.
        let maxCount = 48
        if title.count <= maxCount {
            return title
        }
        return String(title.prefix(maxCount - 1)) + "…"
    }
}
