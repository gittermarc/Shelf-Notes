//
//  AppStartupMaintenanceService.swift
//  Shelf Notes
//
//  Coordinates startup and lifecycle maintenance that used to live directly in RootView.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
enum AppStartupMaintenanceService {
    struct CoverBackfillConfiguration {
        let initialDelayNanoseconds: UInt64
        let batchSize: Int
        let interBatchDelayNanoseconds: UInt64

        static let idle = CoverBackfillConfiguration(
            initialDelayNanoseconds: 1_250_000_000,
            batchSize: 4,
            interBatchDelayNanoseconds: 650_000_000
        )
    }

    static func state(
        scenePhase: ScenePhase,
        didRunCoverBackfill: Bool,
        coverBackfillTask: Task<Void, Never>?,
        didOfferCSVImport: Bool,
        bookCount: Int
    ) -> AppStartupMaintenanceState {
        AppStartupMaintenanceState(
            isSceneActive: scenePhase == .active,
            didRunCoverBackfill: didRunCoverBackfill,
            hasActiveCoverBackfillTask: coverBackfillTask != nil,
            didOfferCSVImport: didOfferCSVImport,
            bookCount: bookCount
        )
    }

    static func tagsIndexSignature(books: [Book]) -> UInt64 {
        TagsIndexStore.taskSignature(books: books)
    }

    static func refreshTagsIndex(
        books: [Book],
        signature: UInt64,
        store: TagsIndexStore
    ) {
        store.update(books: books, signature: signature)
    }

    static func migrateReadingStatusIfNeeded(modelContext: ModelContext) async {
        await ReadingStatusMigrator.migrateIfNeeded(modelContext: modelContext)
    }

    static func bookForPending(
        _ pending: ReadingTimerManager.PendingCompletion,
        books: [Book],
        modelContext: ModelContext
    ) -> Book? {
        if let match = books.first(where: { $0.id == pending.bookID }) {
            return match
        }

        let bookID = pending.bookID
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> { $0.id == bookID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    static func makeCoverBackfillTask(
        modelContext: ModelContext,
        configuration: CoverBackfillConfiguration = .idle,
        shouldContinue: @escaping @MainActor () -> Bool,
        markDidRunCoverBackfill: @escaping @MainActor () -> Void,
        clearCoverBackfillTask: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task(priority: .utility) { @MainActor in
            try? await Task.sleep(nanoseconds: configuration.initialDelayNanoseconds)
            guard !Task.isCancelled, shouldContinue() else {
                clearCoverBackfillTask()
                return
            }

            await CoverThumbnailer.backfillAllBooksIfNeeded(
                modelContext: modelContext,
                batchSize: configuration.batchSize,
                interBatchDelayNanoseconds: configuration.interBatchDelayNanoseconds
            )

            guard !Task.isCancelled else {
                clearCoverBackfillTask()
                return
            }

            markDidRunCoverBackfill()
            clearCoverBackfillTask()
        }
    }
}
