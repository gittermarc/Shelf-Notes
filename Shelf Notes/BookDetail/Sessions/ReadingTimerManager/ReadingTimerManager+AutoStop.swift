//
//  ReadingTimerManager+AutoStop.swift
//  Shelf Notes
//

import Foundation
import SwiftUI

extension ReadingTimerManager {

    // MARK: - Auto-stop (background/inactive)

    var liveActivityAutoStopMinutes: Int? {
        let settings = readAutoStopSettings()
        if let seconds = ReadingTimerAutoStopPolicy.backgroundLimitSeconds(
            expectedExternalReading: active?.expectedExternalReading ?? false,
            autoStopEnabled: settings.enabled,
            autoStopMinutes: settings.minutes
        ) {
            return max(1, Int(ceil(Double(seconds) / 60.0)))
        }
        return nil
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            // When controls were used from the lock screen, the widget extension updated
            // the shared App Group storage. Re-sync when returning to the app.
            syncFromSharedStoreOnAppActive()
        }

        // Auto-stop only applies to an actually running timer.
        guard let a = active, !a.isPaused else {
            clearBackgroundEnteredAt()
            persistActiveIfNeeded()
            return
        }

        switch phase {
        case .inactive, .background:
            setBackgroundEnteredAtIfNeeded(Date())
            persistActive()

        case .active:
            let bgAt = takeBackgroundEnteredAtAndClear() ?? a.lastBackgroundedAt
            guard let bgAt else { return }

            let settings = readAutoStopSettings()
            guard let decision = ReadingTimerAutoStopPolicy.autoStopDecision(
                backgroundEnteredAt: bgAt,
                now: Date(),
                expectedExternalReading: a.expectedExternalReading,
                autoStopEnabled: settings.enabled,
                autoStopMinutes: settings.minutes
            ) else {
                persistActive()
                return
            }

            stop(
                endedAt: decision.endDate,
                wasAutoStopped: true,
                autoStopMinutes: decision.limitMinutes
            )

        @unknown default:
            break
        }
    }

    func readAutoStopSettings() -> AutoStopSettings {
        let d = UserDefaults.standard
        let enabled = d.bool(forKey: Keys.autoStopEnabled)
        let minutes = max(0, d.integer(forKey: Keys.autoStopMinutes))
        return AutoStopSettings(enabled: enabled, minutes: minutes)
    }

    private func persistActiveIfNeeded() {
        if active != nil {
            persistActive()
        }
    }
}
