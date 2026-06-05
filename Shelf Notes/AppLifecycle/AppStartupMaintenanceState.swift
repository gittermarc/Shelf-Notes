//
//  AppStartupMaintenanceState.swift
//  Shelf Notes
//
//  Keeps small startup/lifecycle decisions testable without touching SwiftData.
//

import Foundation

struct AppStartupMaintenanceState: Equatable {
    let isSceneActive: Bool
    let didRunCoverBackfill: Bool
    let hasActiveCoverBackfillTask: Bool
    let didOfferCSVImport: Bool
    let bookCount: Int

    var shouldCancelCoverBackfill: Bool {
        !isSceneActive
    }

    var shouldScheduleCoverBackfill: Bool {
        isSceneActive && !didRunCoverBackfill && !hasActiveCoverBackfillTask
    }

    var shouldOfferCSVImport: Bool {
        !didOfferCSVImport && bookCount == 0
    }
}
