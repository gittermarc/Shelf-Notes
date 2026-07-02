//
//  ReadingSessionActivityAttributes.swift
//  Shelf Notes
//
//  Shared between the main app target and the Live Activity widget extension.
//

import Foundation
import ActivityKit

/// Live Activity attributes for a single active reading session.
nonisolated struct ReadingSessionActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// True when the session is currently paused.
        var isPaused: Bool

        /// For the running state: an "effective" start date so `Text(date, style: .timer)`
        /// shows the correct elapsed duration without frequent updates.
        var effectiveStartDate: Date

        /// For the paused state: frozen duration.
        var pausedElapsedSeconds: Int

        /// Short status text that the extension can show without deriving business state.
        var stateLabel: String?

        /// Current progress payload. Values are optional so old activities and sparse books remain valid.
        var pageCount: Int?
        var pagesRead: Int?
        var remainingPages: Int?
        var progressFraction: Double?

        /// Optional challenge or streak-adjacent motivation payload.
        var challengeTitle: String?
        var challengeDetail: String?
        var challengeProgressFraction: Double?

        /// Cover/theme hints for lightweight refreshes and future presentation variants.
        var hasCover: Bool?
        var coverRevision: Int?
        var accentHex: String?

        /// Changes on app-driven refreshes so ActivityKit can invalidate identical visual payloads.
        var contentUpdatedAt: Date?

        init(
            isPaused: Bool,
            effectiveStartDate: Date,
            pausedElapsedSeconds: Int,
            snapshot: ReadingSessionLiveActivitySnapshot? = nil,
            contentUpdatedAt: Date? = nil
        ) {
            self.isPaused = isPaused
            self.effectiveStartDate = effectiveStartDate
            self.pausedElapsedSeconds = max(0, pausedElapsedSeconds)
            self.stateLabel = isPaused ? ReadingSessionLiveActivitySnapshot.pausedStateLabel : ReadingSessionLiveActivitySnapshot.runningStateLabel
            self.pageCount = snapshot?.pageCount
            self.pagesRead = snapshot?.pagesRead
            self.remainingPages = snapshot?.remainingPages
            self.progressFraction = snapshot?.progressFraction
            self.challengeTitle = snapshot?.challengeTitle
            self.challengeDetail = snapshot?.challengeDetail
            self.challengeProgressFraction = snapshot?.challengeProgressFraction
            self.hasCover = snapshot?.hasCover
            self.coverRevision = snapshot?.coverRevision
            self.accentHex = snapshot?.accentHex
            self.contentUpdatedAt = contentUpdatedAt
        }
    }

    /// Stable identifier to ensure we can re-attach to an existing Activity after relaunch.
    var bookID: String

    /// Human readable title (trimmed + truncated in app before sending).
    var bookTitle: String

    /// Optional display metadata that is stable for the lifetime of the activity.
    var bookAuthor: String?
    var attemptName: String?
    var hasCover: Bool?
    var coverRevision: Int?
    var accentHex: String?

    init(
        bookID: String,
        bookTitle: String,
        bookAuthor: String? = nil,
        attemptName: String? = nil,
        hasCover: Bool? = nil,
        coverRevision: Int? = nil,
        accentHex: String? = nil
    ) {
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.attemptName = attemptName
        self.hasCover = hasCover
        self.coverRevision = coverRevision
        self.accentHex = accentHex
    }

    init(snapshot: ReadingSessionLiveActivitySnapshot) {
        self.init(
            bookID: snapshot.bookID.uuidString,
            bookTitle: snapshot.bookTitle,
            bookAuthor: snapshot.bookAuthor,
            attemptName: snapshot.attemptName,
            hasCover: snapshot.hasCover,
            coverRevision: snapshot.coverRevision,
            accentHex: snapshot.accentHex
        )
    }
}

nonisolated extension ReadingSessionActivityAttributes.ContentState {
    init(active: ReadingTimerActiveBlob, now: Date) {
        let elapsed = active.totalElapsedSeconds(now: now)
        let effectiveStartDate = now.addingTimeInterval(-Double(elapsed))
        self.init(
            isPaused: active.isPaused,
            effectiveStartDate: effectiveStartDate,
            pausedElapsedSeconds: elapsed,
            snapshot: active.liveActivitySnapshot,
            contentUpdatedAt: now
        )
    }
}

nonisolated enum ReadingSessionLiveActivityLifecyclePolicy {
    static let fallbackRunningFreshSeconds = 8 * 60 * 60
    static let pausedFreshSeconds = 12 * 60 * 60
    static let minimumFreshSeconds = 15 * 60
    static let autoStopGraceSeconds = 5 * 60

    static func staleDate(
        now: Date,
        isPaused: Bool,
        autoStopMinutes: Int? = nil
    ) -> Date {
        let seconds: Int

        if isPaused {
            seconds = pausedFreshSeconds
        } else if let autoStopMinutes, autoStopMinutes > 0 {
            seconds = max(
                minimumFreshSeconds,
                autoStopMinutes * 60 + autoStopGraceSeconds
            )
        } else {
            seconds = fallbackRunningFreshSeconds
        }

        return now.addingTimeInterval(TimeInterval(seconds))
    }

    static func staleDate(
        for state: ReadingSessionActivityAttributes.ContentState,
        now: Date,
        autoStopMinutes: Int? = nil
    ) -> Date {
        staleDate(
            now: now,
            isPaused: state.isPaused,
            autoStopMinutes: autoStopMinutes
        )
    }
}

nonisolated enum ReadingSessionLiveActivityDeepLink {
    enum Destination: String, Codable, Hashable, Sendable {
        case session
        case completion
    }

    struct Route: Equatable, Sendable {
        let bookID: UUID
        let destination: Destination
    }

    static let scheme = "shelfnotes"
    static let host = "reading-session"

    static func url(bookID: UUID, destination: Destination = .session) -> URL? {
        url(bookIDString: bookID.uuidString, destination: destination)
    }

    static func url(bookIDString: String, destination: Destination = .session) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "bookID", value: bookIDString),
            URLQueryItem(name: "destination", value: destination.rawValue)
        ]
        return components.url
    }

    static func route(from url: URL) -> Route? {
        guard url.scheme == scheme, url.host == host else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let items = components.queryItems ?? []
        let bookIDString = items.first(where: { $0.name == "bookID" })?.value
        let destinationString = items.first(where: { $0.name == "destination" })?.value

        guard let bookIDString, let bookID = UUID(uuidString: bookIDString) else { return nil }

        let destination = destinationString.flatMap(Destination.init(rawValue:)) ?? .session
        return Route(bookID: bookID, destination: destination)
    }
}

nonisolated enum ReadingSessionDurationFormatter {
    static func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
