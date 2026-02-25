//
//  ReadingTimerManager+AutoStop.swift
//  Shelf Notes
//

import Foundation
import SwiftUI

extension ReadingTimerManager {

    // MARK: - Auto-stop (background/inactive)

    func handleScenePhaseChange(_ phase: ScenePhase) {
        // Auto-stop only applies to an actually running timer.
        guard let a = active, !a.isPaused else {
            clearBackgroundEnteredAt()
            return
        }

        switch phase {
        case .inactive, .background:
            setBackgroundEnteredAtIfNeeded(Date())

        case .active:
            guard let bgAt = takeBackgroundEnteredAtAndClear() else { return }

            let settings = readAutoStopSettings()
            guard settings.enabled, settings.minutes > 0 else { return }

            let awaySeconds = Date().timeIntervalSince(bgAt)
            let thresholdSeconds = TimeInterval(settings.minutes * 60)
            guard awaySeconds >= thresholdSeconds else { return }

            // Stop at the threshold time (not at "now") so we don't log 6-hour naps.
            let autoEnd = bgAt.addingTimeInterval(thresholdSeconds)
            stop(endedAt: autoEnd, wasAutoStopped: true, autoStopMinutes: settings.minutes)

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
}
