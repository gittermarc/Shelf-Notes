//
//  ReadingTimerManager.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 06.01.26.
//

import Foundation
import SwiftUI
import Combine

/// Global manager for a single running “timer reading session”.
///
/// Behavior:
/// - Start: one tap. Keeps running across view changes and even if the app is backgrounded.
/// - Pause/Resume: pauses counting time without discarding the session.
/// - Stop: creates a pending completion state and triggers a sheet (pages + note).
/// - Abort/dismiss: nothing is saved.
/// - Nice-to-have early: auto-stop after X minutes in background/inactive (prevents 6-hour sessions 😄).
@MainActor
final class ReadingTimerManager: ObservableObject {

    // ✅ Fix for Swift 6 / Combine synthesis edge cases:
    // Provide objectWillChange explicitly so ObservableObject conformance is rock-solid.
    // IMPORTANT: With some toolchains, @Published won't reliably trigger UI updates when objectWillChange
    // is provided manually. So we explicitly send objectWillChange in mutating API calls.
    let objectWillChange = ObservableObjectPublisher()

    // MARK: - Published state

    @Published private(set) var active: ActiveState?

    /// When non-nil, `RootView` presents the completion sheet.
    @Published var pendingCompletion: PendingCompletion?

    // MARK: - Stored state

    /// Used for auto-stop while the app is background/inactive.
    /// Kept private, but accessed via small internal helpers so extensions can stay in separate files.
    private var backgroundEnteredAt: Date?

    // MARK: - Live Activity

    let liveActivityCoordinator = ReadingSessionLiveActivityCoordinator()

    // MARK: - Init

    init() {
        registerDefaultsIfNeeded()
        loadPendingCompletionFromDisk()
        loadActiveFromDisk()
    }

    // MARK: - Public API

    var isRunning: Bool {
        guard let a = active else { return false }
        return !a.isPaused
    }

    var isPaused: Bool { active?.isPaused ?? false }

    var activeBookID: UUID? { active?.bookID }
    var activeBookTitle: String? { active?.bookTitle }
    var activeStartedAt: Date? { active?.startedAt }

    /// Starts a timer session. Returns an error message if start is not possible.
    @discardableResult
    func start(
        bookID: UUID,
        bookTitle: String,
        startedAt: Date = Date(),
        coverThumbnailData: Data? = nil,
        liveActivitySnapshot: ReadingSessionLiveActivitySnapshot? = nil,
        sourceSnapshot: ReadingTimerSessionSourceSnapshot = .legacyPhysical
    ) -> String? {
        // Ensure UI updates immediately (BookDetail timer label + Root sheet triggers later).
        objectWillChange.send()

        if pendingCompletion != nil {
            return "Du hast noch eine offene Session (Stop → Sheet). Speichere oder brich sie ab, bevor du eine neue startest."
        }

        if let active = active {
            if active.bookID == bookID {
                // Already running/paused for this book — treat as success/no-op.
                return nil
            }
            return "Es läuft bereits eine Session („\(active.bookTitle)“). Stoppe sie zuerst."
        }

        let safeTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = safeTitle.isEmpty ? "Buch" : safeTitle
        let refreshBookID = bookID
        var normalizedSnapshot = liveActivitySnapshot
        normalizedSnapshot?.stateLabel = ReadingSessionLiveActivitySnapshot.runningStateLabel
        normalizedSnapshot?.applySourceSnapshot(sourceSnapshot)

        self.active = ActiveState(
            bookID: bookID,
            bookTitle: title,
            startedAt: startedAt,
            lastResumedAt: startedAt,
            accumulatedSeconds: 0,
            isPaused: false,
            pausedAt: nil,
            sourceSnapshot: sourceSnapshot,
            liveActivitySnapshot: normalizedSnapshot
        )

        backgroundEnteredAt = nil
        persistActive()
        liveActivityCoordinator.startOrUpdate(
            from: self.active!,
            autoStopMinutes: liveActivityAutoStopMinutes
        )

        if let coverThumbnailData {
            Task.detached(priority: .utility) {
                LiveActivityCoverWriter.writeCoverThumbnailIfPossible(
                    bookID: refreshBookID,
                    sourceThumbnailData: coverThumbnailData
                )

                guard let active = ReadingTimerSharedCodec.decodeActive(
                    from: LiveActivitySharedStore.userDefaults.data(forKey: ReadingTimerSharedKeys.activeBlob)
                ), active.bookID == refreshBookID else {
                    LiveActivitySharedStore.removeCoverFile(bookIDString: refreshBookID.uuidString)
                    return
                }

                // Trigger a lightweight state update so the lock screen re-renders
                // after the cover thumbnail becomes available.
                if #available(iOS 16.2, *) {
                    await ReadingSessionLiveActivityCoordinator.refreshExistingActivityFromSharedState(bookID: refreshBookID)
                }
            }
        }

        // Redundant but harmless — guarantees immediate refresh even if @Published doesn't fire reliably.
        objectWillChange.send()
        return nil
    }

    /// Pauses the current session (keeps it active, but stops counting time).
    func pause(pausedAt: Date = Date()) {
        guard var a = active, !a.isPaused else { return }

        objectWillChange.send()

        let now = pausedAt
        let segment = max(0, Int(now.timeIntervalSince(a.lastResumedAt).rounded()))
        a.accumulatedSeconds = max(0, a.accumulatedSeconds + segment)
        a.isPaused = true
        a.pausedAt = now
        a.clearBackgrounded()
        a.liveActivitySnapshot?.stateLabel = ReadingSessionLiveActivitySnapshot.pausedStateLabel
        active = a

        backgroundEnteredAt = nil
        persistActive()
        liveActivityCoordinator.startOrUpdate(from: a, autoStopMinutes: liveActivityAutoStopMinutes)
        objectWillChange.send()
    }

    /// Resumes a paused session.
    func resume(resumedAt: Date = Date()) {
        guard var a = active, a.isPaused else { return }

        objectWillChange.send()

        a.isPaused = false
        a.pausedAt = nil
        a.lastResumedAt = resumedAt
        a.clearBackgrounded()
        a.liveActivitySnapshot?.stateLabel = ReadingSessionLiveActivitySnapshot.runningStateLabel
        active = a

        backgroundEnteredAt = nil
        persistActive()
        liveActivityCoordinator.startOrUpdate(from: a, autoStopMinutes: liveActivityAutoStopMinutes)
        objectWillChange.send()
    }

    /// Stops the running/paused timer and creates a pending completion.
    func stop(endedAt: Date = Date(), wasAutoStopped: Bool = false, autoStopMinutes: Int? = nil) {
        guard let a = active else { return }

        // Ensure sheet opens immediately (no “only after switching tabs”).
        objectWillChange.send()

        liveActivityCoordinator.endCurrentActivity()

        let end: Date
        if a.isPaused {
            end = a.pausedAt ?? endedAt
        } else {
            end = endedAt
        }

        let duration = totalElapsedSeconds(now: end, active: a)

        pendingCompletion = PendingCompletion(
            bookID: a.bookID,
            bookTitle: a.bookTitle,
            startedAt: a.startedAt,
            endedAt: end,
            durationSeconds: duration,
            wasAutoStopped: wasAutoStopped,
            autoStopMinutes: autoStopMinutes,
            sourceSnapshot: a.sourceSnapshot
        )

        persistPendingCompletion()

        self.active = nil
        backgroundEnteredAt = nil
        clearPersistedActive()
        LiveActivitySharedStore.removeCoverFile(bookIDString: a.bookID.uuidString)

        objectWillChange.send()
    }

    /// Drops the running timer immediately (no pending completion, nothing saved).
    func abortActiveSession() {
        objectWillChange.send()
        liveActivityCoordinator.endCurrentActivity()
        if let bookID = active?.bookID {
            LiveActivitySharedStore.removeCoverFile(bookIDString: bookID.uuidString)
        }
        active = nil
        backgroundEnteredAt = nil
        clearPersistedActive()
        objectWillChange.send()
    }

    /// Drops the pending completion (no save).
    func discardPendingCompletion() {
        objectWillChange.send()
        pendingCompletion = nil
        clearPersistedPendingCompletion()
        objectWillChange.send()
    }

    /// Elapsed seconds for the active timer (supports pause/resume).
    func elapsedSeconds(now: Date = Date()) -> Int {
        guard let a = active else { return 0 }
        return totalElapsedSeconds(now: now, active: a)
    }

    func elapsedString(now: Date = Date()) -> String {
        Self.formatDuration(elapsedSeconds(now: now))
    }

    // MARK: - Extension helpers

    /// Allows split-out extensions to update `active` without making the setter widely accessible.
    func setActiveForInternalUse(_ newValue: ActiveState?) {
        self.active = newValue
    }

    func clearBackgroundEnteredAt() {
        backgroundEnteredAt = nil
        guard var current = active else { return }
        current.clearBackgrounded()
        setActiveForInternalUse(current)
    }

    func setBackgroundEnteredAtIfNeeded(_ date: Date) {
        if backgroundEnteredAt == nil {
            backgroundEnteredAt = date
        }
        guard var current = active else { return }
        current.markBackgroundedIfNeeded(at: date)
        setActiveForInternalUse(current)
    }

    func takeBackgroundEnteredAtAndClear() -> Date? {
        let value = backgroundEnteredAt
        backgroundEnteredAt = nil
        guard var current = active else { return value }
        current.clearBackgrounded()
        setActiveForInternalUse(current)
        return value
    }

    // MARK: - Internal plumbing

    private func totalElapsedSeconds(now: Date, active a: ActiveState) -> Int {
        let base = max(0, a.accumulatedSeconds)
        if a.isPaused {
            return base
        }
        let segment = max(0, Int(now.timeIntervalSince(a.lastResumedAt).rounded()))
        return max(0, base + segment)
    }
}
