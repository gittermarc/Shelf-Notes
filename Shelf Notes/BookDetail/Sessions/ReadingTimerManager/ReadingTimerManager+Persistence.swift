//
//  ReadingTimerManager+Persistence.swift
//  Shelf Notes
//

import Foundation
import Combine

extension ReadingTimerManager {

    // MARK: - Persistence

    func registerDefaultsIfNeeded() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.autoStopEnabled) == nil {
            d.set(true, forKey: Keys.autoStopEnabled)
        }
        if d.object(forKey: Keys.autoStopMinutes) == nil {
            d.set(45, forKey: Keys.autoStopMinutes)
        }
    }

    func persistActive() {
        guard let active = active else { return }
        let blob = ReadingTimerActiveBlob(
            bookID: active.bookID,
            bookTitle: active.bookTitle,
            startedAt: active.startedAt,
            lastResumedAt: active.lastResumedAt,
            accumulatedSeconds: active.accumulatedSeconds,
            isPaused: active.isPaused,
            pausedAt: active.pausedAt,
            readingAttemptID: active.readingAttemptID,
            readingMedium: active.readingMedium,
            readingProvider: active.readingProvider,
            progressUnit: active.progressUnit,
            origin: active.origin,
            expectedExternalReading: active.expectedExternalReading,
            totalValue: active.totalValue,
            lastBackgroundedAt: active.lastBackgroundedAt,
            liveActivitySnapshot: active.liveActivitySnapshot
        )

        if let data = ReadingTimerSharedCodec.encodeActive(blob) {
            LiveActivitySharedStore.userDefaults.set(data, forKey: ReadingTimerSharedKeys.activeBlob)
            notifyLibraryWidgetSnapshotRefresh()
        }
    }

    func loadActiveFromDisk() {
        migrateLegacyActiveBlobIfNeeded()

        guard let data = LiveActivitySharedStore.userDefaults.data(forKey: ReadingTimerSharedKeys.activeBlob) else { return }
        guard let decoded = ReadingTimerSharedCodec.decodeSupportedActive(from: data) else {
            clearPersistedActive()
            liveActivityCoordinator.endCurrentActivity()
            return
        }

        var active = makeActiveState(from: decoded)

        if let decision = restartAutoStopDecision(for: active, now: Date()) {
            setActiveForInternalUse(active)
            stop(
                endedAt: decision.endDate,
                wasAutoStopped: true,
                autoStopMinutes: decision.limitMinutes
            )
            return
        }

        if !active.isPaused, active.lastBackgroundedAt != nil {
            active.clearBackgrounded()
        }

        setActiveForInternalUse(active)
        persistActive()
        liveActivityCoordinator.startOrUpdate(from: active, autoStopMinutes: liveActivityAutoStopMinutes)

        // Ensure any views (e.g. BookDetail) show the running/paused state immediately.
        objectWillChange.send()
    }

    func clearPersistedActive() {
        LiveActivitySharedStore.userDefaults.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
        UserDefaults.standard.removeObject(forKey: Keys.activeBlob)
        LiveActivitySharedStore.removeOrphanedCoverFiles(keepingBookIDStrings: [])
        notifyLibraryWidgetSnapshotRefresh()
    }

    func persistPendingCompletion() {
        guard let pendingCompletion else { return }
        let blob = ReadingTimerPendingCompletionBlob(
            id: pendingCompletion.id,
            bookID: pendingCompletion.bookID,
            bookTitle: pendingCompletion.bookTitle,
            startedAt: pendingCompletion.startedAt,
            endedAt: pendingCompletion.endedAt,
            durationSeconds: pendingCompletion.durationSeconds,
            wasAutoStopped: pendingCompletion.wasAutoStopped,
            autoStopMinutes: pendingCompletion.autoStopMinutes,
            readingAttemptID: pendingCompletion.readingAttemptID,
            readingMedium: pendingCompletion.readingMedium,
            readingProvider: pendingCompletion.readingProvider,
            progressUnit: pendingCompletion.progressUnit,
            origin: pendingCompletion.origin,
            expectedExternalReading: pendingCompletion.expectedExternalReading,
            totalValue: pendingCompletion.totalValue
        )
        if let data = ReadingTimerSharedCodec.encodePendingCompletion(blob) {
            LiveActivitySharedStore.userDefaults.set(data, forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
        }
    }

    func loadPendingCompletionFromDisk() {
        guard let data = LiveActivitySharedStore.userDefaults.data(forKey: ReadingTimerSharedKeys.pendingCompletionBlob) else { return }
        guard let decoded = ReadingTimerSharedCodec.decodeSupportedPendingCompletion(from: data) else {
            clearPersistedPendingCompletion()
            return
        }

        pendingCompletion = makePendingCompletion(from: decoded)
    }

    func clearPersistedPendingCompletion() {
        LiveActivitySharedStore.userDefaults.removeObject(forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
    }

    private func notifyLibraryWidgetSnapshotRefresh() {
        LibraryWidgetSnapshotRefreshNotification.post()
    }

    func syncFromSharedStoreOnAppActive() {
        objectWillChange.send()
        loadPendingCompletionFromDisk()

        let shared = LiveActivitySharedStore.userDefaults
        if let data = shared.data(forKey: ReadingTimerSharedKeys.activeBlob) {
            if let decoded = ReadingTimerSharedCodec.decodeSupportedActive(from: data) {
                let mapped = makeActiveState(from: decoded)

                if active != mapped {
                    setActiveForInternalUse(mapped)
                    if mapped.isPaused {
                        clearBackgroundEnteredAt()
                    } else if let lastBackgroundedAt = mapped.lastBackgroundedAt {
                        setBackgroundEnteredAtIfNeeded(lastBackgroundedAt)
                    } else {
                        clearBackgroundEnteredAt()
                    }
                    liveActivityCoordinator.startOrUpdate(from: mapped, autoStopMinutes: liveActivityAutoStopMinutes)
                }
            } else {
                clearPersistedActive()
                liveActivityCoordinator.endCurrentActivity()
                setActiveForInternalUse(nil)
            }
        } else {
            if active != nil {
                setActiveForInternalUse(nil)
                clearBackgroundEnteredAt()
                liveActivityCoordinator.endCurrentActivity()
                LiveActivitySharedStore.removeOrphanedCoverFiles(keepingBookIDStrings: [])
            }
        }

        objectWillChange.send()
    }

    // MARK: - Migration

    private func migrateLegacyActiveBlobIfNeeded() {
        let shared = LiveActivitySharedStore.userDefaults
        if shared.data(forKey: ReadingTimerSharedKeys.activeBlob) != nil {
            return
        }

        // Phase 1 stored the active blob in standard defaults.
        if let data = UserDefaults.standard.data(forKey: Keys.activeBlob) {
            shared.set(data, forKey: ReadingTimerSharedKeys.activeBlob)
            UserDefaults.standard.removeObject(forKey: Keys.activeBlob)
        }
    }

    private func makeActiveState(from decoded: ReadingTimerActiveBlob) -> ActiveState {
        ActiveState(
            bookID: decoded.bookID,
            bookTitle: decoded.bookTitle,
            startedAt: decoded.startedAt,
            lastResumedAt: decoded.lastResumedAt,
            accumulatedSeconds: decoded.accumulatedSeconds,
            isPaused: decoded.isPaused,
            pausedAt: decoded.pausedAt,
            sourceSnapshot: decoded.sourceSnapshot,
            lastBackgroundedAt: decoded.lastBackgroundedAt,
            liveActivitySnapshot: decoded.liveActivitySnapshot
        )
    }

    private func makePendingCompletion(from decoded: ReadingTimerPendingCompletionBlob) -> PendingCompletion {
        PendingCompletion(
            id: decoded.id,
            bookID: decoded.bookID,
            bookTitle: decoded.bookTitle,
            startedAt: decoded.startedAt,
            endedAt: decoded.endedAt,
            durationSeconds: decoded.durationSeconds,
            wasAutoStopped: decoded.wasAutoStopped,
            autoStopMinutes: decoded.autoStopMinutes,
            sourceSnapshot: decoded.sourceSnapshot
        )
    }

    private func restartAutoStopDecision(for active: ActiveState, now: Date) -> ReadingTimerAutoStopPolicy.Decision? {
        guard !active.isPaused, let lastBackgroundedAt = active.lastBackgroundedAt else {
            return nil
        }

        let settings = readAutoStopSettings()
        return ReadingTimerAutoStopPolicy.autoStopDecision(
            backgroundEnteredAt: lastBackgroundedAt,
            now: now,
            expectedExternalReading: active.expectedExternalReading,
            autoStopEnabled: settings.enabled,
            autoStopMinutes: settings.minutes
        )
    }
}
