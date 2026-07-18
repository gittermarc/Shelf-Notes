//
//  ReadingTimerSessionPolicy.swift
//  Shelf Notes
//
//  Shared timer source snapshot and lifecycle policy for app and Live Activity.
//

import Foundation

nonisolated struct ReadingTimerSessionSourceSnapshot: Codable, Equatable, Hashable, Sendable {
    var readingAttemptID: UUID?
    var readingMedium: ReadingMedium
    var readingProvider: ReadingProvider
    var progressUnit: ReadingProgressUnit
    var origin: ReadingSessionOrigin
    var expectedExternalReading: Bool
    var totalValue: Double?

    init(
        readingAttemptID: UUID? = nil,
        readingMedium: ReadingMedium = .physical,
        readingProvider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        origin: ReadingSessionOrigin = .legacy,
        expectedExternalReading: Bool? = nil,
        totalValue: Double? = nil
    ) {
        self.readingAttemptID = readingAttemptID
        self.readingMedium = readingMedium
        self.readingProvider = readingProvider
        self.progressUnit = progressUnit
        self.origin = origin
        self.expectedExternalReading = expectedExternalReading ?? Self.defaultExpectedExternalReading(
            medium: readingMedium,
            provider: readingProvider,
            origin: origin
        )
        self.totalValue = Self.normalizedTotalValue(totalValue)
    }

    static let legacyPhysical = ReadingTimerSessionSourceSnapshot(
        readingAttemptID: nil,
        readingMedium: .physical,
        readingProvider: .none,
        progressUnit: .pages,
        origin: .legacy,
        expectedExternalReading: false,
        totalValue: nil
    )

    static func defaultExpectedExternalReading(
        medium: ReadingMedium,
        provider: ReadingProvider,
        origin: ReadingSessionOrigin
    ) -> Bool {
        guard medium == .ebook else { return false }
        guard provider != .localFile else { return false }
        guard origin != .integratedReader else { return false }
        return true
    }

    private static func normalizedTotalValue(_ raw: Double?) -> Double? {
        guard let raw, raw.isFinite, raw > 0 else { return nil }
        return raw
    }
}

nonisolated enum ReadingTimerAutoStopPolicy {
    struct Decision: Equatable, Sendable {
        let endDate: Date
        let limitSeconds: Int

        var limitMinutes: Int {
            max(1, Int(ceil(Double(limitSeconds) / 60.0)))
        }
    }

    static let externalReadingSafetySeconds = 8 * 60 * 60
    static let fallbackRunningFreshSeconds = 8 * 60 * 60
    static let pausedFreshSeconds = 12 * 60 * 60
    static let minimumFreshSeconds = 15 * 60
    static let autoStopGraceSeconds = 5 * 60

    static func backgroundLimitSeconds(
        expectedExternalReading: Bool,
        autoStopEnabled: Bool,
        autoStopMinutes: Int
    ) -> Int? {
        if expectedExternalReading {
            return externalReadingSafetySeconds
        }

        guard autoStopEnabled, autoStopMinutes > 0 else { return nil }
        return autoStopMinutes * 60
    }

    static func autoStopDecision(
        backgroundEnteredAt: Date,
        now: Date,
        expectedExternalReading: Bool,
        autoStopEnabled: Bool,
        autoStopMinutes: Int
    ) -> Decision? {
        guard let limitSeconds = backgroundLimitSeconds(
            expectedExternalReading: expectedExternalReading,
            autoStopEnabled: autoStopEnabled,
            autoStopMinutes: autoStopMinutes
        ) else {
            return nil
        }

        let awaySeconds = now.timeIntervalSince(backgroundEnteredAt)
        guard awaySeconds >= TimeInterval(limitSeconds) else { return nil }

        return Decision(
            endDate: backgroundEnteredAt.addingTimeInterval(TimeInterval(limitSeconds)),
            limitSeconds: limitSeconds
        )
    }

    static func staleDate(
        now: Date,
        isPaused: Bool,
        expectedExternalReading: Bool,
        autoStopEnabled: Bool,
        autoStopMinutes: Int
    ) -> Date {
        let seconds: Int

        if isPaused {
            seconds = pausedFreshSeconds
        } else if let limitSeconds = backgroundLimitSeconds(
            expectedExternalReading: expectedExternalReading,
            autoStopEnabled: autoStopEnabled,
            autoStopMinutes: autoStopMinutes
        ) {
            seconds = max(
                minimumFreshSeconds,
                limitSeconds + autoStopGraceSeconds
            )
        } else {
            seconds = fallbackRunningFreshSeconds
        }

        return now.addingTimeInterval(TimeInterval(seconds))
    }
}
