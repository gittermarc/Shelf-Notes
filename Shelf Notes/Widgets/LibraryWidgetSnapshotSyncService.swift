//
//  LibraryWidgetSnapshotSyncService.swift
//  Shelf Notes
//
//  App-side refresh bridge for the future Library Home Screen widget.
//  The service fetches SwiftData models in the app process, builds a value snapshot,
//  writes it into the App Group and asks WidgetKit for a targeted timeline refresh.
//

import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class LibraryWidgetSnapshotSyncService {
    enum RefreshReason: String, Hashable, Sendable {
        case startup
        case appBecameActive
        case modelContextSave
        case manual
    }

    static let widgetKind = "LibraryOverviewWidget"
    static let shared = LibraryWidgetSnapshotSyncService()

    private let store: LibraryWidgetSnapshotStore
    private let nowProvider: () -> Date
    private let calendarProvider: () -> Calendar
    private let reloadTimelines: @MainActor (String) -> Void
    private let debounceNanoseconds: UInt64
    private var pendingRefreshTask: Task<Void, Never>?

    init(
        store: LibraryWidgetSnapshotStore = LibraryWidgetSnapshotStore(),
        debounceNanoseconds: UInt64 = 1_000_000_000,
        nowProvider: @escaping () -> Date = Date.init,
        calendarProvider: @escaping () -> Calendar = { .current },
        reloadTimelines: @escaping @MainActor (String) -> Void = { kind in
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
            #else
            _ = kind
            #endif
        }
    ) {
        self.store = store
        self.debounceNanoseconds = debounceNanoseconds
        self.nowProvider = nowProvider
        self.calendarProvider = calendarProvider
        self.reloadTimelines = reloadTimelines
    }

    deinit {
        pendingRefreshTask?.cancel()
    }

    func scheduleRefresh(
        modelContext: ModelContext,
        reason: RefreshReason,
        delayNanoseconds: UInt64? = nil
    ) {
        pendingRefreshTask?.cancel()
        let delay = delayNanoseconds ?? debounceNanoseconds

        pendingRefreshTask = Task { @MainActor [weak self, modelContext] in
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }
            }

            self?.refreshNow(modelContext: modelContext, reason: reason)
        }
    }

    @discardableResult
    func refreshNow(
        modelContext: ModelContext,
        reason: RefreshReason = .manual,
        generatedAt: Date? = nil,
        calendar: Calendar? = nil
    ) -> LibraryWidgetSnapshot? {
        let now = generatedAt ?? nowProvider()
        let resolvedCalendar = calendar ?? calendarProvider()
        let snapshot = makeSnapshot(
            modelContext: modelContext,
            generatedAt: now,
            calendar: resolvedCalendar
        )

        let previous = store.load()
        guard previous?.hasSameRenderableContent(as: snapshot) != true else {
            return snapshot
        }

        guard store.save(snapshot) else {
            return nil
        }

        reloadTimelines(Self.widgetKind)
        return snapshot
    }

    private func makeSnapshot(
        modelContext: ModelContext,
        generatedAt: Date,
        calendar: Calendar
    ) -> LibraryWidgetSnapshot {
        let books = fetchBooks(modelContext: modelContext)
        let goals = fetchGoals(modelContext: modelContext)
        let recentActivity = ProgressHubSessionMetricsProvider.makeSnapshot(
            modelContext: modelContext,
            now: generatedAt,
            calendar: calendar
        ).recentActivity

        return LibraryWidgetSnapshotBuilder.make(
            books: LibraryWidgetSnapshotInputMapper.bookRecords(from: books),
            goals: LibraryWidgetSnapshotInputMapper.goalRecords(from: goals),
            recentActivity: recentActivity,
            activeBookID: activeTimerBookID(),
            generatedAt: generatedAt,
            calendar: calendar
        )
    }

    private func fetchBooks(modelContext: ModelContext) -> [Book] {
        let descriptor = FetchDescriptor<Book>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchGoals(modelContext: ModelContext) -> [ReadingGoal] {
        let descriptor = FetchDescriptor<ReadingGoal>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func activeTimerBookID() -> UUID? {
        let data = LiveActivitySharedStore.userDefaults.data(forKey: ReadingTimerSharedKeys.activeBlob)
        return ReadingTimerSharedCodec.decodeSupportedActive(from: data)?.bookID
    }
}
