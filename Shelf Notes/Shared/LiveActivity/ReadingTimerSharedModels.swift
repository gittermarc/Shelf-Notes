//
//  ReadingTimerSharedModels.swift
//  Shelf Notes
//
//  Codable wire models used to share the timer session state between
//  the main app and the Live Activity extension.
//

import Foundation

nonisolated enum ReadingTimerSharedKeys {
    /// Stored in App Group UserDefaults.
    static let activeBlob: String = "reading_timer_active_v1"

    /// Stored in App Group UserDefaults.
    static let pendingCompletionBlob: String = "reading_timer_pending_completion_v1"
}

nonisolated enum ReadingTimerSharedCodec {
    static func decodeActive(from data: Data?) -> ReadingTimerActiveBlob? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ReadingTimerActiveBlob.self, from: data)
    }

    static func decodePendingCompletion(from data: Data?) -> ReadingTimerPendingCompletionBlob? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ReadingTimerPendingCompletionBlob.self, from: data)
    }

    static func decodeSupportedActive(from data: Data?) -> ReadingTimerActiveBlob? {
        guard let blob = decodeActive(from: data), blob.hasSupportedSchemaVersion else { return nil }
        return blob
    }

    static func decodeSupportedPendingCompletion(from data: Data?) -> ReadingTimerPendingCompletionBlob? {
        guard let blob = decodePendingCompletion(from: data), blob.hasSupportedSchemaVersion else { return nil }
        return blob
    }

    static func encodeActive(_ blob: ReadingTimerActiveBlob) -> Data? {
        try? JSONEncoder().encode(blob)
    }

    static func encodePendingCompletion(_ blob: ReadingTimerPendingCompletionBlob) -> Data? {
        try? JSONEncoder().encode(blob)
    }
}

/// Shared, Codable representation of the current active timer session.
///
/// This is intentionally duplicated (instead of referencing `ReadingTimerManager.ActiveState`)
/// so the widget extension can decode it without importing the app module.
nonisolated struct ReadingTimerActiveBlob: Codable, Equatable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var bookID: UUID
    var bookTitle: String
    var startedAt: Date
    var lastResumedAt: Date
    var accumulatedSeconds: Int
    var isPaused: Bool
    var pausedAt: Date?
    var readingAttemptID: UUID?
    var readingMedium: ReadingMedium
    var readingProvider: ReadingProvider
    var progressUnit: ReadingProgressUnit
    var origin: ReadingSessionOrigin
    var expectedExternalReading: Bool
    var totalValue: Double?
    var lastBackgroundedAt: Date?
    var liveActivitySnapshot: ReadingSessionLiveActivitySnapshot?

    init(
        schemaVersion: Int = ReadingTimerActiveBlob.currentSchemaVersion,
        bookID: UUID,
        bookTitle: String,
        startedAt: Date,
        lastResumedAt: Date,
        accumulatedSeconds: Int,
        isPaused: Bool,
        pausedAt: Date?,
        readingAttemptID: UUID? = nil,
        readingMedium: ReadingMedium = .physical,
        readingProvider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        origin: ReadingSessionOrigin = .legacy,
        expectedExternalReading: Bool? = nil,
        totalValue: Double? = nil,
        lastBackgroundedAt: Date? = nil,
        liveActivitySnapshot: ReadingSessionLiveActivitySnapshot? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.bookID = bookID
        self.bookTitle = Self.normalizedTitle(bookTitle)
        self.startedAt = startedAt
        self.lastResumedAt = lastResumedAt
        self.accumulatedSeconds = max(0, accumulatedSeconds)
        self.isPaused = isPaused
        self.pausedAt = isPaused ? (pausedAt ?? lastResumedAt) : pausedAt
        self.readingAttemptID = readingAttemptID
        self.readingMedium = readingMedium
        self.readingProvider = readingProvider
        self.progressUnit = progressUnit
        self.origin = origin
        self.expectedExternalReading = expectedExternalReading ?? ReadingTimerSessionSourceSnapshot.defaultExpectedExternalReading(
            medium: readingMedium,
            provider: readingProvider,
            origin: origin
        )
        self.totalValue = Self.normalizedPositiveDouble(totalValue)
        self.lastBackgroundedAt = isPaused ? nil : lastBackgroundedAt

        var snapshot = liveActivitySnapshot
        snapshot?.applySourceSnapshot(sourceSnapshot)
        self.liveActivitySnapshot = snapshot
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case bookID
        case bookTitle
        case startedAt
        case lastResumedAt
        case accumulatedSeconds
        case isPaused
        case pausedAt
        case readingAttemptID
        case readingMedium
        case readingProvider
        case progressUnit
        case origin
        case expectedExternalReading
        case totalValue
        case lastBackgroundedAt
        case liveActivitySnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bookID = try container.decode(UUID.self, forKey: .bookID)
        let title = (try? container.decode(String.self, forKey: .bookTitle)) ?? ReadingSessionLiveActivitySnapshot.defaultTitle
        let startedAt = (try? container.decode(Date.self, forKey: .startedAt)) ?? Date()
        let lastResumedAt = (try? container.decode(Date.self, forKey: .lastResumedAt)) ?? startedAt
        let accumulatedSeconds = (try? container.decode(Int.self, forKey: .accumulatedSeconds)) ?? 0
        let isPaused = (try? container.decode(Bool.self, forKey: .isPaused)) ?? false
        let pausedAt = try? container.decode(Date.self, forKey: .pausedAt)
        let readingAttemptID = try? container.decode(UUID.self, forKey: .readingAttemptID)
        let readingMedium = (try? container.decode(ReadingMedium.self, forKey: .readingMedium)) ?? .physical
        let readingProvider = (try? container.decode(ReadingProvider.self, forKey: .readingProvider)) ?? .none
        let progressUnit = (try? container.decode(ReadingProgressUnit.self, forKey: .progressUnit)) ?? .pages
        let origin = (try? container.decode(ReadingSessionOrigin.self, forKey: .origin)) ?? .legacy
        let expectedExternalReading = try? container.decode(Bool.self, forKey: .expectedExternalReading)
        let totalValue = try? container.decode(Double.self, forKey: .totalValue)
        let lastBackgroundedAt = try? container.decode(Date.self, forKey: .lastBackgroundedAt)
        let snapshot = try? container.decode(ReadingSessionLiveActivitySnapshot.self, forKey: .liveActivitySnapshot)
        let schemaVersion = (try? container.decode(Int.self, forKey: .schemaVersion)) ?? 1

        self.init(
            schemaVersion: schemaVersion,
            bookID: bookID,
            bookTitle: title,
            startedAt: startedAt,
            lastResumedAt: lastResumedAt,
            accumulatedSeconds: accumulatedSeconds,
            isPaused: isPaused,
            pausedAt: pausedAt,
            readingAttemptID: readingAttemptID,
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: totalValue,
            lastBackgroundedAt: lastBackgroundedAt,
            liveActivitySnapshot: snapshot
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bookID, forKey: .bookID)
        try container.encode(bookTitle, forKey: .bookTitle)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(lastResumedAt, forKey: .lastResumedAt)
        try container.encode(accumulatedSeconds, forKey: .accumulatedSeconds)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encodeIfPresent(pausedAt, forKey: .pausedAt)
        try container.encodeIfPresent(readingAttemptID, forKey: .readingAttemptID)
        try container.encode(readingMedium, forKey: .readingMedium)
        try container.encode(readingProvider, forKey: .readingProvider)
        try container.encode(progressUnit, forKey: .progressUnit)
        try container.encode(origin, forKey: .origin)
        try container.encode(expectedExternalReading, forKey: .expectedExternalReading)
        try container.encodeIfPresent(totalValue, forKey: .totalValue)
        try container.encodeIfPresent(lastBackgroundedAt, forKey: .lastBackgroundedAt)
        try container.encodeIfPresent(liveActivitySnapshot, forKey: .liveActivitySnapshot)
    }

    var hasSupportedSchemaVersion: Bool {
        schemaVersion > 0 && schemaVersion <= Self.currentSchemaVersion
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

    func totalElapsedSeconds(now: Date) -> Int {
        let base = max(0, accumulatedSeconds)
        if isPaused {
            return base
        }
        let segment = max(0, Int(now.timeIntervalSince(lastResumedAt).rounded()))
        return max(0, base + segment)
    }

    mutating func pause(now: Date) {
        guard !isPaused else { return }
        let segment = max(0, Int(now.timeIntervalSince(lastResumedAt).rounded()))
        accumulatedSeconds = max(0, accumulatedSeconds + segment)
        isPaused = true
        pausedAt = now
        lastBackgroundedAt = nil
        liveActivitySnapshot?.stateLabel = ReadingSessionLiveActivitySnapshot.pausedStateLabel
    }

    mutating func resume(now: Date) {
        guard isPaused else { return }
        isPaused = false
        pausedAt = nil
        lastResumedAt = now
        lastBackgroundedAt = nil
        liveActivitySnapshot?.stateLabel = ReadingSessionLiveActivitySnapshot.runningStateLabel
    }

    private static func normalizedTitle(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? ReadingSessionLiveActivitySnapshot.defaultTitle : value
    }

    private static func normalizedPositiveDouble(_ raw: Double?) -> Double? {
        guard let raw, raw.isFinite, raw > 0 else { return nil }
        return raw
    }
}

/// Shared, Codable representation of a timer session completion that still needs user input.
nonisolated struct ReadingTimerPendingCompletionBlob: Codable, Equatable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var id: UUID
    var bookID: UUID
    var bookTitle: String
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var wasAutoStopped: Bool
    var autoStopMinutes: Int?
    var readingAttemptID: UUID?
    var readingMedium: ReadingMedium
    var readingProvider: ReadingProvider
    var progressUnit: ReadingProgressUnit
    var origin: ReadingSessionOrigin
    var expectedExternalReading: Bool
    var totalValue: Double?

    init(
        schemaVersion: Int = ReadingTimerPendingCompletionBlob.currentSchemaVersion,
        id: UUID,
        bookID: UUID,
        bookTitle: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        wasAutoStopped: Bool,
        autoStopMinutes: Int?,
        readingAttemptID: UUID? = nil,
        readingMedium: ReadingMedium = .physical,
        readingProvider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        origin: ReadingSessionOrigin = .legacy,
        expectedExternalReading: Bool? = nil,
        totalValue: Double? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.bookID = bookID
        self.bookTitle = Self.normalizedTitle(bookTitle)
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.wasAutoStopped = wasAutoStopped
        self.autoStopMinutes = autoStopMinutes
        self.readingAttemptID = readingAttemptID
        self.readingMedium = readingMedium
        self.readingProvider = readingProvider
        self.progressUnit = progressUnit
        self.origin = origin
        self.expectedExternalReading = expectedExternalReading ?? ReadingTimerSessionSourceSnapshot.defaultExpectedExternalReading(
            medium: readingMedium,
            provider: readingProvider,
            origin: origin
        )
        self.totalValue = Self.normalizedPositiveDouble(totalValue)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case bookID
        case bookTitle
        case startedAt
        case endedAt
        case durationSeconds
        case wasAutoStopped
        case autoStopMinutes
        case readingAttemptID
        case readingMedium
        case readingProvider
        case progressUnit
        case origin
        case expectedExternalReading
        case totalValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        let bookID = try container.decode(UUID.self, forKey: .bookID)
        let title = (try? container.decode(String.self, forKey: .bookTitle)) ?? ReadingSessionLiveActivitySnapshot.defaultTitle
        let startedAt = (try? container.decode(Date.self, forKey: .startedAt)) ?? Date()
        let endedAt = (try? container.decode(Date.self, forKey: .endedAt)) ?? startedAt
        let durationSeconds = (try? container.decode(Int.self, forKey: .durationSeconds)) ?? 0
        let wasAutoStopped = (try? container.decode(Bool.self, forKey: .wasAutoStopped)) ?? false
        let autoStopMinutes = try? container.decode(Int.self, forKey: .autoStopMinutes)
        let readingAttemptID = try? container.decode(UUID.self, forKey: .readingAttemptID)
        let readingMedium = (try? container.decode(ReadingMedium.self, forKey: .readingMedium)) ?? .physical
        let readingProvider = (try? container.decode(ReadingProvider.self, forKey: .readingProvider)) ?? .none
        let progressUnit = (try? container.decode(ReadingProgressUnit.self, forKey: .progressUnit)) ?? .pages
        let origin = (try? container.decode(ReadingSessionOrigin.self, forKey: .origin)) ?? .legacy
        let expectedExternalReading = try? container.decode(Bool.self, forKey: .expectedExternalReading)
        let totalValue = try? container.decode(Double.self, forKey: .totalValue)
        let schemaVersion = (try? container.decode(Int.self, forKey: .schemaVersion)) ?? 1

        self.init(
            schemaVersion: schemaVersion,
            id: id,
            bookID: bookID,
            bookTitle: title,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            wasAutoStopped: wasAutoStopped,
            autoStopMinutes: autoStopMinutes,
            readingAttemptID: readingAttemptID,
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: totalValue
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(bookID, forKey: .bookID)
        try container.encode(bookTitle, forKey: .bookTitle)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(wasAutoStopped, forKey: .wasAutoStopped)
        try container.encodeIfPresent(autoStopMinutes, forKey: .autoStopMinutes)
        try container.encodeIfPresent(readingAttemptID, forKey: .readingAttemptID)
        try container.encode(readingMedium, forKey: .readingMedium)
        try container.encode(readingProvider, forKey: .readingProvider)
        try container.encode(progressUnit, forKey: .progressUnit)
        try container.encode(origin, forKey: .origin)
        try container.encode(expectedExternalReading, forKey: .expectedExternalReading)
        try container.encodeIfPresent(totalValue, forKey: .totalValue)
    }

    var hasSupportedSchemaVersion: Bool {
        schemaVersion > 0 && schemaVersion <= Self.currentSchemaVersion
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

    private static func normalizedTitle(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? ReadingSessionLiveActivitySnapshot.defaultTitle : value
    }

    private static func normalizedPositiveDouble(_ raw: Double?) -> Double? {
        guard let raw, raw.isFinite, raw > 0 else { return nil }
        return raw
    }
}
