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
            let data = try JSONEncoder().encode(active)
            UserDefaults.standard.set(data, forKey: Keys.activeBlob)
        } catch {
            // If persistence fails, we still keep the in-memory timer running.
        }
    }

    func loadActiveFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Keys.activeBlob) else { return }
        do {
            let decoded = try JSONDecoder().decode(ActiveState.self, from: data)
            setActiveForInternalUse(decoded)

            // Ensure any views (e.g. BookDetail) show the running/paused state immediately.
            objectWillChange.send()
        } catch {
            clearPersistedActive()
        }
    }

    func clearPersistedActive() {
        UserDefaults.standard.removeObject(forKey: Keys.activeBlob)
    }
}
