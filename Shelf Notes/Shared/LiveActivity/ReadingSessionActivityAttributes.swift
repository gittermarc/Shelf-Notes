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
        var locator: String?

        /// Source snapshot captured when the timer started.
        var readingAttemptID: UUID?
        var readingMedium: ReadingMedium
        var readingProvider: ReadingProvider
        var progressUnit: ReadingProgressUnit
        var origin: ReadingSessionOrigin
        var expectedExternalReading: Bool
        var totalValue: Double?

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
            source: ReadingTimerSessionSourceSnapshot? = nil,
            contentUpdatedAt: Date? = nil
        ) {
            let resolvedSource = source ?? snapshot?.sourceSnapshot ?? .legacyPhysical
            self.isPaused = isPaused
            self.effectiveStartDate = effectiveStartDate
            self.pausedElapsedSeconds = max(0, pausedElapsedSeconds)
            self.stateLabel = isPaused ? ReadingSessionLiveActivitySnapshot.pausedStateLabel : ReadingSessionLiveActivitySnapshot.runningStateLabel
            self.pageCount = resolvedSource.progressUnit == .pages ? snapshot?.pageCount : nil
            self.pagesRead = resolvedSource.progressUnit == .pages ? snapshot?.pagesRead : nil
            self.remainingPages = resolvedSource.progressUnit == .pages ? snapshot?.remainingPages : nil
            self.progressFraction = snapshot?.progressFraction
            self.locator = snapshot?.locator
            self.readingAttemptID = resolvedSource.readingAttemptID
            self.readingMedium = resolvedSource.readingMedium
            self.readingProvider = resolvedSource.readingProvider
            self.progressUnit = resolvedSource.progressUnit
            self.origin = resolvedSource.origin
            self.expectedExternalReading = resolvedSource.expectedExternalReading
            self.totalValue = resolvedSource.totalValue
            self.challengeTitle = snapshot?.challengeTitle
            self.challengeDetail = snapshot?.challengeDetail
            self.challengeProgressFraction = snapshot?.challengeProgressFraction
            self.hasCover = snapshot?.hasCover
            self.coverRevision = snapshot?.coverRevision
            self.accentHex = snapshot?.accentHex
            self.contentUpdatedAt = contentUpdatedAt
        }

        enum CodingKeys: String, CodingKey {
            case isPaused
            case effectiveStartDate
            case pausedElapsedSeconds
            case stateLabel
            case pageCount
            case pagesRead
            case remainingPages
            case progressFraction
            case locator
            case readingAttemptID
            case readingMedium
            case readingProvider
            case progressUnit
            case origin
            case expectedExternalReading
            case totalValue
            case challengeTitle
            case challengeDetail
            case challengeProgressFraction
            case hasCover
            case coverRevision
            case accentHex
            case contentUpdatedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let isPaused = (try? container.decode(Bool.self, forKey: .isPaused)) ?? false
            let effectiveStartDate = (try? container.decode(Date.self, forKey: .effectiveStartDate)) ?? Date()
            let pausedElapsedSeconds = (try? container.decode(Int.self, forKey: .pausedElapsedSeconds)) ?? 0
            let readingMedium = (try? container.decode(ReadingMedium.self, forKey: .readingMedium)) ?? .physical
            let readingProvider = (try? container.decode(ReadingProvider.self, forKey: .readingProvider)) ?? .none
            let progressUnit = (try? container.decode(ReadingProgressUnit.self, forKey: .progressUnit)) ?? .pages
            let origin = (try? container.decode(ReadingSessionOrigin.self, forKey: .origin)) ?? .legacy
            let expectedExternalReading = try? container.decode(Bool.self, forKey: .expectedExternalReading)
            let source = ReadingTimerSessionSourceSnapshot(
                readingAttemptID: try? container.decode(UUID.self, forKey: .readingAttemptID),
                readingMedium: readingMedium,
                readingProvider: readingProvider,
                progressUnit: progressUnit,
                origin: origin,
                expectedExternalReading: expectedExternalReading,
                totalValue: try? container.decode(Double.self, forKey: .totalValue)
            )

            self.init(
                isPaused: isPaused,
                effectiveStartDate: effectiveStartDate,
                pausedElapsedSeconds: pausedElapsedSeconds,
                snapshot: nil,
                source: source,
                contentUpdatedAt: try? container.decode(Date.self, forKey: .contentUpdatedAt)
            )

            self.stateLabel = (try? container.decode(String.self, forKey: .stateLabel)) ?? self.stateLabel
            if progressUnit == .pages {
                self.pageCount = try? container.decode(Int.self, forKey: .pageCount)
                self.pagesRead = try? container.decode(Int.self, forKey: .pagesRead)
                self.remainingPages = try? container.decode(Int.self, forKey: .remainingPages)
            } else {
                self.pageCount = nil
                self.pagesRead = nil
                self.remainingPages = nil
            }
            self.progressFraction = try? container.decode(Double.self, forKey: .progressFraction)
            self.locator = try? container.decode(String.self, forKey: .locator)
            self.challengeTitle = try? container.decode(String.self, forKey: .challengeTitle)
            self.challengeDetail = try? container.decode(String.self, forKey: .challengeDetail)
            self.challengeProgressFraction = try? container.decode(Double.self, forKey: .challengeProgressFraction)
            self.hasCover = try? container.decode(Bool.self, forKey: .hasCover)
            self.coverRevision = try? container.decode(Int.self, forKey: .coverRevision)
            self.accentHex = try? container.decode(String.self, forKey: .accentHex)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(isPaused, forKey: .isPaused)
            try container.encode(effectiveStartDate, forKey: .effectiveStartDate)
            try container.encode(pausedElapsedSeconds, forKey: .pausedElapsedSeconds)
            try container.encodeIfPresent(stateLabel, forKey: .stateLabel)
            try container.encodeIfPresent(pageCount, forKey: .pageCount)
            try container.encodeIfPresent(pagesRead, forKey: .pagesRead)
            try container.encodeIfPresent(remainingPages, forKey: .remainingPages)
            try container.encodeIfPresent(progressFraction, forKey: .progressFraction)
            try container.encodeIfPresent(locator, forKey: .locator)
            try container.encodeIfPresent(readingAttemptID, forKey: .readingAttemptID)
            try container.encode(readingMedium, forKey: .readingMedium)
            try container.encode(readingProvider, forKey: .readingProvider)
            try container.encode(progressUnit, forKey: .progressUnit)
            try container.encode(origin, forKey: .origin)
            try container.encode(expectedExternalReading, forKey: .expectedExternalReading)
            try container.encodeIfPresent(totalValue, forKey: .totalValue)
            try container.encodeIfPresent(challengeTitle, forKey: .challengeTitle)
            try container.encodeIfPresent(challengeDetail, forKey: .challengeDetail)
            try container.encodeIfPresent(challengeProgressFraction, forKey: .challengeProgressFraction)
            try container.encodeIfPresent(hasCover, forKey: .hasCover)
            try container.encodeIfPresent(coverRevision, forKey: .coverRevision)
            try container.encodeIfPresent(accentHex, forKey: .accentHex)
            try container.encodeIfPresent(contentUpdatedAt, forKey: .contentUpdatedAt)
        }
    }

    /// Stable identifier to ensure we can re-attach to an existing Activity after relaunch.
    var bookID: String

    /// Human readable title (trimmed + truncated in app before sending).
    var bookTitle: String

    /// Optional display metadata that is stable for the lifetime of the activity.
    var bookAuthor: String?
    var attemptName: String?

    /// Source snapshot captured when the timer started.
    var readingAttemptID: UUID?
    var readingMedium: ReadingMedium
    var readingProvider: ReadingProvider
    var progressUnit: ReadingProgressUnit
    var origin: ReadingSessionOrigin
    var expectedExternalReading: Bool
    var totalValue: Double?

    var hasCover: Bool?
    var coverRevision: Int?
    var accentHex: String?

    init(
        bookID: String,
        bookTitle: String,
        bookAuthor: String? = nil,
        attemptName: String? = nil,
        readingAttemptID: UUID? = nil,
        readingMedium: ReadingMedium = .physical,
        readingProvider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        origin: ReadingSessionOrigin = .legacy,
        expectedExternalReading: Bool? = nil,
        totalValue: Double? = nil,
        hasCover: Bool? = nil,
        coverRevision: Int? = nil,
        accentHex: String? = nil
    ) {
        let source = ReadingTimerSessionSourceSnapshot(
            readingAttemptID: readingAttemptID,
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: totalValue
        )
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.attemptName = attemptName
        self.readingAttemptID = source.readingAttemptID
        self.readingMedium = source.readingMedium
        self.readingProvider = source.readingProvider
        self.progressUnit = source.progressUnit
        self.origin = source.origin
        self.expectedExternalReading = source.expectedExternalReading
        self.totalValue = source.totalValue
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
            readingAttemptID: snapshot.readingAttemptID,
            readingMedium: snapshot.readingMedium,
            readingProvider: snapshot.readingProvider,
            progressUnit: snapshot.progressUnit,
            origin: snapshot.origin,
            expectedExternalReading: snapshot.expectedExternalReading,
            totalValue: snapshot.totalValue,
            hasCover: snapshot.hasCover,
            coverRevision: snapshot.coverRevision,
            accentHex: snapshot.accentHex
        )
    }

    var sourceSnapshot: ReadingTimerSessionSourceSnapshot {
        ReadingTimerSessionSourceSnapshot(
            readingAttemptID: readingAttemptID,
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: totalValue
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
            source: active.sourceSnapshot,
            contentUpdatedAt: now
        )
    }

    var sourceSnapshot: ReadingTimerSessionSourceSnapshot {
        ReadingTimerSessionSourceSnapshot(
            readingAttemptID: readingAttemptID,
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: totalValue
        )
    }
}

nonisolated enum ReadingSessionLiveActivityLifecyclePolicy {
    static let fallbackRunningFreshSeconds = ReadingTimerAutoStopPolicy.fallbackRunningFreshSeconds
    static let pausedFreshSeconds = ReadingTimerAutoStopPolicy.pausedFreshSeconds
    static let minimumFreshSeconds = ReadingTimerAutoStopPolicy.minimumFreshSeconds
    static let autoStopGraceSeconds = ReadingTimerAutoStopPolicy.autoStopGraceSeconds

    static func staleDate(
        now: Date,
        isPaused: Bool,
        autoStopMinutes: Int? = nil,
        expectedExternalReading: Bool = false
    ) -> Date {
        ReadingTimerAutoStopPolicy.staleDate(
            now: now,
            isPaused: isPaused,
            expectedExternalReading: expectedExternalReading,
            autoStopEnabled: autoStopMinutes != nil,
            autoStopMinutes: autoStopMinutes ?? 0
        )
    }

    static func staleDate(
        for state: ReadingSessionActivityAttributes.ContentState,
        now: Date,
        autoStopMinutes: Int? = nil
    ) -> Date {
        staleDate(
            now: now,
            isPaused: state.isPaused,
            autoStopMinutes: autoStopMinutes,
            expectedExternalReading: state.expectedExternalReading
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
