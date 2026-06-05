import Testing
@testable import Shelf_Notes

struct AppStartupMaintenanceStateTests {
    @Test func schedulesCoverBackfillOnlyWhenActivePendingAndIdle() {
        let ready = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: false,
            didOfferCSVImport: true,
            bookCount: 12
        )

        let inactive = AppStartupMaintenanceState(
            isSceneActive: false,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: false,
            didOfferCSVImport: true,
            bookCount: 12
        )

        let alreadyDone = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: true,
            hasActiveCoverBackfillTask: false,
            didOfferCSVImport: true,
            bookCount: 12
        )

        let alreadyRunning = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: true,
            didOfferCSVImport: true,
            bookCount: 12
        )

        #expect(ready.shouldScheduleCoverBackfill)
        #expect(!inactive.shouldScheduleCoverBackfill)
        #expect(!alreadyDone.shouldScheduleCoverBackfill)
        #expect(!alreadyRunning.shouldScheduleCoverBackfill)
    }

    @Test func cancelsCoverBackfillOutsideActiveScene() {
        let active = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: true,
            didOfferCSVImport: true,
            bookCount: 3
        )

        let background = AppStartupMaintenanceState(
            isSceneActive: false,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: true,
            didOfferCSVImport: true,
            bookCount: 3
        )

        #expect(!active.shouldCancelCoverBackfill)
        #expect(background.shouldCancelCoverBackfill)
    }

    @Test func offersCSVImportOnlyOnceForEmptyLibraries() {
        let firstEmptyLaunch = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: false,
            didOfferCSVImport: false,
            bookCount: 0
        )

        let alreadyOffered = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: false,
            didOfferCSVImport: true,
            bookCount: 0
        )

        let nonEmptyLibrary = AppStartupMaintenanceState(
            isSceneActive: true,
            didRunCoverBackfill: false,
            hasActiveCoverBackfillTask: false,
            didOfferCSVImport: false,
            bookCount: 1
        )

        #expect(firstEmptyLaunch.shouldOfferCSVImport)
        #expect(!alreadyOffered.shouldOfferCSVImport)
        #expect(!nonEmptyLibrary.shouldOfferCSVImport)
    }
}
