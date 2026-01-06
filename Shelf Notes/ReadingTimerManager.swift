//
//  ReadingTimerManager.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 06.01.26.
//

import Foundation
import SwiftUI
import Combine

/// Global manager for a single running “timer reading session”.
///
/// Behavior:
/// - Start: one tap. Keeps running across view changes and even if the app is backgrounded.
/// - Stop: creates a pending completion state and triggers a sheet (pages + note).
/// - Abort/dismiss: nothing is saved.
/// - Nice-to-have early: auto-stop after X minutes in background/inactive (prevents 6-hour sessions 😄).
@MainActor
final class ReadingTimerManager: ObservableObject {

    // ✅ Fix for Swift 6 / Combine synthesis edge cases:
    // Provide objectWillChange explicitly so ObservableObject conformance is rock-solid.
    // IMPORTANT: With some toolchains, @Published won't reliably trigger UI updates when objectWillChange
    // is provided manually. So we explicitly send objectWillChange in mutating API calls.
    let objectWillChange = ObservableObjectPublisher()

    // MARK: - Types

    struct ActiveState: Codable, Equatable {
        var bookID: UUID
        var bookTitle: String
        var startedAt: Date
    }

    struct PendingCompletion: Identifiable, Equatable {
        let id: UUID
        var bookID: UUID
        var bookTitle: String
        var startedAt: Date
        var endedAt: Date
        var wasAutoStopped: Bool
        var autoStopMinutes: Int?

        init(
            bookID: UUID,
            bookTitle: String,
            startedAt: Date,
            endedAt: Date,
            wasAutoStopped: Bool,
            autoStopMinutes: Int?
        ) {
            self.id = UUID()
            self.bookID = bookID
            self.bookTitle = bookTitle
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.wasAutoStopped = wasAutoStopped
            self.autoStopMinutes = autoStopMinutes
        }

        var durationSeconds: Int {
            max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
        }
    }

    // MARK: - Published state

    @Published private(set) var active: ActiveState?

    /// When non-nil, `RootView` presents the completion sheet.
    @Published var pendingCompletion: PendingCompletion?

    // MARK: - Private

    private var backgroundEnteredAt: Date?

    private enum Keys {
        static let activeBlob = "reading_timer_active_v1"
        static let autoStopEnabled = "session_autostop_enabled_v1"
        static let autoStopMinutes = "session_autostop_minutes_v1"
    }

    // MARK: - Init

    init() {
        registerDefaultsIfNeeded()
        loadActiveFromDisk()
    }

    // MARK: - Public API

    var isRunning: Bool { active != nil }

    var activeBookID: UUID? { active?.bookID }
    var activeBookTitle: String? { active?.bookTitle }
    var activeStartedAt: Date? { active?.startedAt }

    /// Starts a timer session. Returns an error message if start is not possible.
    @discardableResult
    func start(bookID: UUID, bookTitle: String, startedAt: Date = Date()) -> String? {
        // Ensure UI updates immediately (BookDetail timer label + Root sheet triggers later).
        objectWillChange.send()

        if pendingCompletion != nil {
            return "Du hast noch eine offene Session (Stop → Sheet). Speichere oder brich sie ab, bevor du eine neue startest."
        }

        if let active = active {
            if active.bookID == bookID {
                // Already running for this book — treat as success/no-op.
                return nil
            }
            return "Es läuft bereits eine Session („\(active.bookTitle)“). Stoppe sie zuerst."
        }

        let safeTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.active = ActiveState(
            bookID: bookID,
            bookTitle: safeTitle.isEmpty ? "Buch" : safeTitle,
            startedAt: startedAt
        )
        backgroundEnteredAt = nil
        persistActive()

        // Redundant but harmless — guarantees immediate refresh even if @Published doesn't fire reliably.
        objectWillChange.send()
        return nil
    }

    /// Stops the running timer and creates a pending completion.
    func stop(endedAt: Date = Date(), wasAutoStopped: Bool = false, autoStopMinutes: Int? = nil) {
        guard let active = active else { return }

        // Ensure sheet opens immediately (no “only after switching tabs”).
        objectWillChange.send()

        let end = max(endedAt, active.startedAt)

        pendingCompletion = PendingCompletion(
            bookID: active.bookID,
            bookTitle: active.bookTitle,
            startedAt: active.startedAt,
            endedAt: end,
            wasAutoStopped: wasAutoStopped,
            autoStopMinutes: autoStopMinutes
        )

        self.active = nil
        backgroundEnteredAt = nil
        clearPersistedActive()

        objectWillChange.send()
    }

    /// Drops the running timer immediately (no pending completion, nothing saved).
    func abortActiveSession() {
        objectWillChange.send()
        active = nil
        backgroundEnteredAt = nil
        clearPersistedActive()
        objectWillChange.send()
    }

    /// Drops the pending completion (no save).
    func discardPendingCompletion() {
        objectWillChange.send()
        pendingCompletion = nil
        objectWillChange.send()
    }

    /// Elapsed seconds for the active timer.
    func elapsedSeconds(now: Date = Date()) -> Int {
        guard let start = active?.startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(start).rounded()))
    }

    func elapsedString(now: Date = Date()) -> String {
        Self.formatDuration(elapsedSeconds(now: now))
    }

    // MARK: - Auto-stop (background/inactive)

    func handleScenePhaseChange(_ phase: ScenePhase) {
        guard active != nil else {
            backgroundEnteredAt = nil
            return
        }

        switch phase {
        case .inactive, .background:
            if backgroundEnteredAt == nil { backgroundEnteredAt = Date() }

        case .active:
            guard let bgAt = backgroundEnteredAt else { return }
            backgroundEnteredAt = nil

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

    // MARK: - Formatting

    static func formatDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }

    // MARK: - Persistence

    private func registerDefaultsIfNeeded() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.autoStopEnabled) == nil {
            d.set(true, forKey: Keys.autoStopEnabled)
        }
        if d.object(forKey: Keys.autoStopMinutes) == nil {
            d.set(45, forKey: Keys.autoStopMinutes)
        }
    }

    private func readAutoStopSettings() -> (enabled: Bool, minutes: Int) {
        let d = UserDefaults.standard
        let enabled = d.bool(forKey: Keys.autoStopEnabled)
        let minutes = max(0, d.integer(forKey: Keys.autoStopMinutes))
        return (enabled, minutes)
    }

    private func persistActive() {
        guard let active = active else { return }
        do {
            let data = try JSONEncoder().encode(active)
            UserDefaults.standard.set(data, forKey: Keys.activeBlob)
        } catch {
            // If persistence fails, we still keep the in-memory timer running.
        }
    }

    private func loadActiveFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Keys.activeBlob) else { return }
        do {
            let decoded = try JSONDecoder().decode(ActiveState.self, from: data)
            self.active = decoded

            // Ensure any views (e.g. BookDetail) show the running state immediately.
            objectWillChange.send()
        } catch {
            clearPersistedActive()
        }
    }

    private func clearPersistedActive() {
        UserDefaults.standard.removeObject(forKey: Keys.activeBlob)
    }
}
