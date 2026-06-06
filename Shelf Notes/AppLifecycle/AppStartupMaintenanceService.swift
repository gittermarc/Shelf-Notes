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
        bookCount: Int?
    ) -> AppStartupMaintenanceState {
        AppStartupMaintenanceState(
            isSceneActive: scenePhase == .active,
            didRunCoverBackfill: didRunCoverBackfill,
            hasActiveCoverBackfillTask: coverBackfillTask != nil,
            didOfferCSVImport: didOfferCSVImport,
            bookCount: bookCount
        )
    }

    static func fetchBookCount(modelContext: ModelContext) -> Int? {
        let descriptor = FetchDescriptor<Book>()
        return try? modelContext.fetchCount(descriptor)
    }

    static func refreshTagsIndex(
        modelContext: ModelContext,
        store: TagsIndexStore
    ) {
        let snapshot = fetchTagSuggestionSnapshot(modelContext: modelContext)
        store.update(suggestionSnapshots: snapshot)
    }

    static func fetchBookTagsSnapshot(modelContext: ModelContext) -> [TagsIndexBuilder.BookTagsSnapshot] {
        let descriptor = FetchDescriptor<Book>(
            sortBy: [SortDescriptor(\Book.createdAt, order: .reverse)]
        )

        let books = (try? modelContext.fetch(descriptor)) ?? []
        return TagsIndexBuilder.makeSnapshot(books: books)
            .sorted { lhs, rhs in
                lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func fetchTagSuggestionSnapshot(modelContext: ModelContext) -> [TagSuggestionBookSnapshot] {
        let descriptor = FetchDescriptor<Book>(
            sortBy: [SortDescriptor(\Book.createdAt, order: .reverse)]
        )

        let books = (try? modelContext.fetch(descriptor)) ?? []
        return TagsIndexBuilder.makeSuggestionSnapshot(books: books)
            .sorted { lhs, rhs in
                lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func migrateReadingStatusIfNeeded(modelContext: ModelContext) async {
        await ReadingStatusMigrator.migrateIfNeeded(modelContext: modelContext)
    }

    static func bookForPending(
        _ pending: ReadingTimerManager.PendingCompletion,
        modelContext: ModelContext
    ) -> Book? {
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
