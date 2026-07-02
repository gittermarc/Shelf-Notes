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
        do {
            let blob = ReadingTimerActiveBlob(
                bookID: active.bookID,
                bookTitle: active.bookTitle,
                startedAt: active.startedAt,
                lastResumedAt: active.lastResumedAt,
                accumulatedSeconds: active.accumulatedSeconds,
                isPaused: active.isPaused,
                pausedAt: active.pausedAt,
                liveActivitySnapshot: active.liveActivitySnapshot
            )

            let data = try JSONEncoder().encode(blob)
            LiveActivitySharedStore.userDefaults.set(data, forKey: ReadingTimerSharedKeys.activeBlob)
        } catch {
            // If persistence fails, we still keep the in-memory timer running.
        }
    }

    func loadActiveFromDisk() {
        migrateLegacyActiveBlobIfNeeded()

        guard let data = LiveActivitySharedStore.userDefaults.data(forKey: ReadingTimerSharedKeys.activeBlob) else { return }
        do {
            let decoded = try JSONDecoder().decode(ReadingTimerActiveBlob.self, from: data)

            let active = ActiveState(
                bookID: decoded.bookID,
                bookTitle: decoded.bookTitle,
                startedAt: decoded.startedAt,
                lastResumedAt: decoded.lastResumedAt,
                accumulatedSeconds: decoded.accumulatedSeconds,
                isPaused: decoded.isPaused,
                pausedAt: decoded.pausedAt,
                liveActivitySnapshot: decoded.liveActivitySnapshot
            )

            setActiveForInternalUse(active)
            liveActivityCoordinator.startOrUpdate(from: active)

            // Ensure any views (e.g. BookDetail) show the running/paused state immediately.
            objectWillChange.send()
        } catch {
            clearPersistedActive()
            liveActivityCoordinator.endCurrentActivity()
        }
    }

    func clearPersistedActive() {
        LiveActivitySharedStore.userDefaults.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
        UserDefaults.standard.removeObject(forKey: Keys.activeBlob)
    }

    func persistPendingCompletion() {
        guard let pendingCompletion else { return }
        do {
            let blob = ReadingTimerPendingCompletionBlob(
                id: pendingCompletion.id,
                bookID: pendingCompletion.bookID,
                bookTitle: pendingCompletion.bookTitle,
                startedAt: pendingCompletion.startedAt,
                endedAt: pendingCompletion.endedAt,
                durationSeconds: pendingCompletion.durationSeconds,
                wasAutoStopped: pendingCompletion.wasAutoStopped,
                autoStopMinutes: pendingCompletion.autoStopMinutes
            )
            let data = try JSONEncoder().encode(blob)
            LiveActivitySharedStore.userDefaults.set(data, forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
        } catch {
            // Non-fatal.
        }
    }

    func loadPendingCompletionFromDisk() {
        guard let data = LiveActivitySharedStore.userDefaults.data(forKey: ReadingTimerSharedKeys.pendingCompletionBlob) else { return }
        do {
            let decoded = try JSONDecoder().decode(ReadingTimerPendingCompletionBlob.self, from: data)
            let pending = PendingCompletion(
                id: decoded.id,
                bookID: decoded.bookID,
                bookTitle: decoded.bookTitle,
                startedAt: decoded.startedAt,
                endedAt: decoded.endedAt,
                durationSeconds: decoded.durationSeconds,
                wasAutoStopped: decoded.wasAutoStopped,
                autoStopMinutes: decoded.autoStopMinutes
            )
            pendingCompletion = pending
        } catch {
            clearPersistedPendingCompletion()
        }
    }

    func clearPersistedPendingCompletion() {
        LiveActivitySharedStore.userDefaults.removeObject(forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
    }

    func syncFromSharedStoreOnAppActive() {
        objectWillChange.send()
        loadPendingCompletionFromDisk()

        let shared = LiveActivitySharedStore.userDefaults
        if let data = shared.data(forKey: ReadingTimerSharedKeys.activeBlob) {
            do {
                let decoded = try JSONDecoder().decode(ReadingTimerActiveBlob.self, from: data)
                let mapped = ActiveState(
                    bookID: decoded.bookID,
                    bookTitle: decoded.bookTitle,
                    startedAt: decoded.startedAt,
                    lastResumedAt: decoded.lastResumedAt,
                    accumulatedSeconds: decoded.accumulatedSeconds,
                    isPaused: decoded.isPaused,
                    pausedAt: decoded.pausedAt,
                    liveActivitySnapshot: decoded.liveActivitySnapshot
                )

                if active != mapped {
                    setActiveForInternalUse(mapped)
                    clearBackgroundEnteredAt()
                    liveActivityCoordinator.startOrUpdate(from: mapped)
                }
            } catch {
                clearPersistedActive()
                liveActivityCoordinator.endCurrentActivity()
                setActiveForInternalUse(nil)
            }
        } else {
            if active != nil {
                setActiveForInternalUse(nil)
                clearBackgroundEnteredAt()
                liveActivityCoordinator.endCurrentActivity()
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
}
