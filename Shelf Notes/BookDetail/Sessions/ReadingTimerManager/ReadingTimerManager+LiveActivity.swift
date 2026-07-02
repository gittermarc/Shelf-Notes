//
//  ReadingTimerManager+LiveActivity.swift
//  Shelf Notes
//
//  Keeps the active timer's Live Activity snapshot in sync with app-side state.
//

import Foundation
import Combine

extension ReadingTimerManager {
    func updateLiveActivitySnapshot(_ snapshot: ReadingSessionLiveActivitySnapshot) {
        guard var activeState = active, activeState.bookID == snapshot.bookID else { return }

        var normalizedSnapshot = snapshot
        normalizedSnapshot.stateLabel = activeState.isPaused
            ? ReadingSessionLiveActivitySnapshot.pausedStateLabel
            : ReadingSessionLiveActivitySnapshot.runningStateLabel

        guard activeState.liveActivitySnapshot != normalizedSnapshot else { return }

        objectWillChange.send()
        activeState.liveActivitySnapshot = normalizedSnapshot
        setActiveForInternalUse(activeState)
        persistActive()
        liveActivityCoordinator.startOrUpdate(from: activeState)
        objectWillChange.send()
    }
}
