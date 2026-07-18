import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingTimerExternalSessionTests {
    @Test func activeBlobRoundTripsCurrentSchemaWithSourceSnapshot() throws {
        let now = Date(timeIntervalSince1970: 100_000)
        let attemptID = UUID(uuidString: "A57C8016-F170-4053-990F-23689471B73C")!
        let bookID = UUID(uuidString: "DB9BD997-9537-483C-8964-A65671106B7B")!
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: "External",
            progressFraction: 0.42,
            readingAttemptID: attemptID,
            readingMedium: .ebook,
            readingProvider: .kindle,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100,
            hasCover: false
        )
        let blob = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "External",
            startedAt: now.addingTimeInterval(-600),
            lastResumedAt: now.addingTimeInterval(-300),
            accumulatedSeconds: 300,
            isPaused: false,
            pausedAt: nil,
            readingAttemptID: attemptID,
            readingMedium: .ebook,
            readingProvider: .kindle,
            progressUnit: .percentage,
            origin: .timer,
            expectedExternalReading: true,
            totalValue: 100,
            lastBackgroundedAt: now.addingTimeInterval(-120),
            liveActivitySnapshot: snapshot
        )

        let data = try #require(ReadingTimerSharedCodec.encodeActive(blob))
        let decoded = try #require(ReadingTimerSharedCodec.decodeSupportedActive(from: data))

        #expect(decoded.schemaVersion == ReadingTimerActiveBlob.currentSchemaVersion)
        #expect(decoded.readingAttemptID == attemptID)
        #expect(decoded.readingMedium == .ebook)
        #expect(decoded.readingProvider == .kindle)
        #expect(decoded.progressUnit == .percentage)
        #expect(decoded.origin == .timer)
        #expect(decoded.expectedExternalReading)
        #expect(decoded.totalValue == 100)
        #expect(decoded.lastBackgroundedAt == now.addingTimeInterval(-120))
        #expect(decoded.liveActivitySnapshot?.sourceSnapshot == decoded.sourceSnapshot)
    }

    @Test func pendingCompletionRoundTripsCurrentSchemaWithAttemptAndSource() throws {
        let now = Date(timeIntervalSince1970: 110_000)
        let attemptID = UUID(uuidString: "2299F832-D120-4724-B15D-71AB5EF182E4")!
        let pending = ReadingTimerPendingCompletionBlob(
            id: UUID(uuidString: "AA468DC1-0F30-462B-BFD9-8D152A3BD180")!,
            bookID: UUID(uuidString: "244D4535-9599-4B6B-AB49-1524893F1C39")!,
            bookTitle: "Pending External",
            startedAt: now.addingTimeInterval(-900),
            endedAt: now,
            durationSeconds: 900,
            wasAutoStopped: false,
            autoStopMinutes: nil,
            readingAttemptID: attemptID,
            readingMedium: .ebook,
            readingProvider: .appleBooks,
            progressUnit: .percentage,
            origin: .timer,
            expectedExternalReading: true,
            totalValue: 100
        )

        let data = try #require(ReadingTimerSharedCodec.encodePendingCompletion(pending))
        let decoded = try #require(ReadingTimerSharedCodec.decodeSupportedPendingCompletion(from: data))

        #expect(decoded.schemaVersion == ReadingTimerPendingCompletionBlob.currentSchemaVersion)
        #expect(decoded.readingAttemptID == attemptID)
        #expect(decoded.readingMedium == .ebook)
        #expect(decoded.readingProvider == .appleBooks)
        #expect(decoded.progressUnit == .percentage)
        #expect(decoded.origin == .timer)
        #expect(decoded.expectedExternalReading)
        #expect(decoded.totalValue == 100)
    }

    @Test func legacyActiveSchemasDecodeAsPhysicalSessions() throws {
        let now = Date(timeIntervalSince1970: 120_000)
        let bookID = UUID(uuidString: "AC527219-E1AA-41C7-B527-C56416CB7A9B")!
        let payloads: [Data] = [
            try JSONEncoder().encode(LegacyActiveV1(
                bookID: bookID,
                bookTitle: "Legacy One",
                startedAt: now.addingTimeInterval(-120),
                lastResumedAt: now.addingTimeInterval(-60),
                accumulatedSeconds: 60,
                isPaused: false,
                pausedAt: nil
            )),
            try JSONEncoder().encode(LegacyActiveV2(
                schemaVersion: 2,
                bookID: bookID,
                bookTitle: "Legacy Two",
                startedAt: now.addingTimeInterval(-240),
                lastResumedAt: now.addingTimeInterval(-120),
                accumulatedSeconds: 120,
                isPaused: true,
                pausedAt: nil,
                liveActivitySnapshot: nil
            ))
        ]

        for data in payloads {
            let decoded = try #require(ReadingTimerSharedCodec.decodeSupportedActive(from: data))
            #expect(decoded.readingAttemptID == nil)
            #expect(decoded.readingMedium == .physical)
            #expect(decoded.readingProvider == .none)
            #expect(decoded.progressUnit == .pages)
            #expect(decoded.origin == .legacy)
            #expect(!decoded.expectedExternalReading)
            #expect(decoded.totalValue == nil)
        }
    }

    @Test func legacyPendingSchemasDecodeAsPhysicalCompletions() throws {
        let now = Date(timeIntervalSince1970: 130_000)
        let bookID = UUID(uuidString: "65F7B43D-B918-40C5-9B9C-93B0195892EC")!
        let payloads: [Data] = [
            try JSONEncoder().encode(LegacyPendingV1(
                id: UUID(),
                bookID: bookID,
                bookTitle: "Legacy Pending One",
                startedAt: now.addingTimeInterval(-600),
                endedAt: now,
                durationSeconds: 600,
                wasAutoStopped: false,
                autoStopMinutes: nil
            )),
            try JSONEncoder().encode(LegacyPendingV2(
                schemaVersion: 2,
                id: UUID(),
                bookID: bookID,
                bookTitle: "Legacy Pending Two",
                startedAt: now.addingTimeInterval(-300),
                endedAt: now,
                durationSeconds: 300,
                wasAutoStopped: true,
                autoStopMinutes: 45
            ))
        ]

        for data in payloads {
            let decoded = try #require(ReadingTimerSharedCodec.decodeSupportedPendingCompletion(from: data))
            #expect(decoded.readingAttemptID == nil)
            #expect(decoded.readingMedium == .physical)
            #expect(decoded.readingProvider == .none)
            #expect(decoded.progressUnit == .pages)
            #expect(decoded.origin == .legacy)
            #expect(!decoded.expectedExternalReading)
            #expect(decoded.totalValue == nil)
        }
    }

    @Test func futureSchemasAreRejectedBySupportedCodecs() throws {
        let active = ReadingTimerActiveBlob(
            schemaVersion: ReadingTimerActiveBlob.currentSchemaVersion + 10,
            bookID: UUID(),
            bookTitle: "Future",
            startedAt: Date(timeIntervalSince1970: 140_000),
            lastResumedAt: Date(timeIntervalSince1970: 140_000),
            accumulatedSeconds: 0,
            isPaused: false,
            pausedAt: nil
        )
        let pending = ReadingTimerPendingCompletionBlob(
            schemaVersion: ReadingTimerPendingCompletionBlob.currentSchemaVersion + 10,
            id: UUID(),
            bookID: UUID(),
            bookTitle: "Future Pending",
            startedAt: Date(timeIntervalSince1970: 140_000),
            endedAt: Date(timeIntervalSince1970: 140_060),
            durationSeconds: 60,
            wasAutoStopped: false,
            autoStopMinutes: nil
        )

        #expect(ReadingTimerSharedCodec.decodeSupportedActive(from: ReadingTimerSharedCodec.encodeActive(active)) == nil)
        #expect(ReadingTimerSharedCodec.decodeSupportedPendingCompletion(from: ReadingTimerSharedCodec.encodePendingCompletion(pending)) == nil)
    }

    @Test func externalReadingDoesNotAutoStopAtPhysicalBackgroundLimit() {
        let entered = Date(timeIntervalSince1970: 150_000)
        let now = entered.addingTimeInterval(TimeInterval(46 * 60))

        let decision = ReadingTimerAutoStopPolicy.autoStopDecision(
            backgroundEnteredAt: entered,
            now: now,
            expectedExternalReading: true,
            autoStopEnabled: true,
            autoStopMinutes: 45
        )

        #expect(decision == nil)
    }

    @Test func externalReadingUsesLongSafetyLimit() throws {
        let entered = Date(timeIntervalSince1970: 160_000)
        let now = entered.addingTimeInterval(TimeInterval(8 * 60 * 60 + 1))

        let decision = try #require(ReadingTimerAutoStopPolicy.autoStopDecision(
            backgroundEnteredAt: entered,
            now: now,
            expectedExternalReading: true,
            autoStopEnabled: false,
            autoStopMinutes: 0
        ))

        #expect(decision.endDate == entered.addingTimeInterval(TimeInterval(8 * 60 * 60)))
        #expect(decision.limitMinutes == 480)
    }

    @Test func physicalReadingKeepsConfiguredAutoStopPolicy() throws {
        let entered = Date(timeIntervalSince1970: 170_000)
        let before = ReadingTimerAutoStopPolicy.autoStopDecision(
            backgroundEnteredAt: entered,
            now: entered.addingTimeInterval(TimeInterval(44 * 60 + 59)),
            expectedExternalReading: false,
            autoStopEnabled: true,
            autoStopMinutes: 45
        )
        let after = try #require(ReadingTimerAutoStopPolicy.autoStopDecision(
            backgroundEnteredAt: entered,
            now: entered.addingTimeInterval(TimeInterval(45 * 60)),
            expectedExternalReading: false,
            autoStopEnabled: true,
            autoStopMinutes: 45
        ))

        #expect(before == nil)
        #expect(after.endDate == entered.addingTimeInterval(TimeInterval(45 * 60)))
        #expect(after.limitMinutes == 45)
    }

    @Test func staleDatesCoverPausedRunningAndExternalSessions() {
        let now = Date(timeIntervalSince1970: 180_000)
        let paused = ReadingTimerAutoStopPolicy.staleDate(
            now: now,
            isPaused: true,
            expectedExternalReading: true,
            autoStopEnabled: true,
            autoStopMinutes: 45
        )
        let runningPhysical = ReadingTimerAutoStopPolicy.staleDate(
            now: now,
            isPaused: false,
            expectedExternalReading: false,
            autoStopEnabled: true,
            autoStopMinutes: 45
        )
        let runningExternal = ReadingTimerAutoStopPolicy.staleDate(
            now: now,
            isPaused: false,
            expectedExternalReading: true,
            autoStopEnabled: false,
            autoStopMinutes: 0
        )

        #expect(paused == now.addingTimeInterval(TimeInterval(12 * 60 * 60)))
        #expect(runningPhysical == now.addingTimeInterval(TimeInterval(50 * 60)))
        #expect(runningExternal == now.addingTimeInterval(TimeInterval(8 * 60 * 60 + 5 * 60)))
    }

    @Test  func pendingCompletionStoresAttemptAndSourceSnapshot() {
        let attemptID = UUID(uuidString: "8FF81132-A124-47D6-A359-5F192730306B")!
        let source = ReadingTimerSessionSourceSnapshot(
            readingAttemptID: attemptID,
            readingMedium: .ebook,
            readingProvider: .googleBooks,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100
        )
        let pending = ReadingTimerManager.PendingCompletion(
            bookID: UUID(),
            bookTitle: "Pending",
            startedAt: Date(timeIntervalSince1970: 190_000),
            endedAt: Date(timeIntervalSince1970: 190_600),
            durationSeconds: 600,
            wasAutoStopped: false,
            autoStopMinutes: nil,
            sourceSnapshot: source
        )

        #expect(pending.readingAttemptID == attemptID)
        #expect(pending.readingMedium == .ebook)
        #expect(pending.readingProvider == .googleBooks)
        #expect(pending.progressUnit == .percentage)
        #expect(pending.origin == .timer)
        #expect(pending.expectedExternalReading)
        #expect(pending.totalValue == 100)
    }

    @Test func sharedStorePauseAndStopPreserveSource() throws {
        let defaultsName = "ReadingTimerExternalSessionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let now = Date(timeIntervalSince1970: 200_000)
        let attemptID = UUID(uuidString: "4D153196-38D2-41E1-92D6-97937AE472C5")!
        let bookID = UUID(uuidString: "56CEF459-06F8-4E1B-95B3-853B24572B8D")!
        let active = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "Shared",
            startedAt: now.addingTimeInterval(-120),
            lastResumedAt: now.addingTimeInterval(-120),
            accumulatedSeconds: 0,
            isPaused: false,
            pausedAt: nil,
            readingAttemptID: attemptID,
            readingMedium: .ebook,
            readingProvider: .kindle,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100
        )
        defaults.set(try #require(ReadingTimerSharedCodec.encodeActive(active)), forKey: ReadingTimerSharedKeys.activeBlob)

        let pauseResult = LiveActivitySharedStore.togglePauseForActiveSession(
            bookID: bookID,
            now: now,
            defaults: defaults
        )
        guard case .updated(let paused) = pauseResult else {
            Issue.record("Expected shared pause mutation to update active state")
            return
        }
        #expect(paused.isPaused)
        #expect(paused.sourceSnapshot == active.sourceSnapshot)

        let stopResult = LiveActivitySharedStore.stopActiveSession(
            bookID: bookID,
            now: now.addingTimeInterval(30),
            pendingID: UUID(uuidString: "B2DDB847-9779-49BC-8684-87BE0130D64C")!,
            defaults: defaults,
            removeCover: false
        )
        guard case .stopped(let stoppedActive, let pending) = stopResult else {
            Issue.record("Expected shared stop mutation to create pending completion")
            return
        }

        #expect(stoppedActive.sourceSnapshot == active.sourceSnapshot)
        #expect(pending.sourceSnapshot == active.sourceSnapshot)
        #expect(defaults.data(forKey: ReadingTimerSharedKeys.activeBlob) == nil)
        #expect(defaults.data(forKey: ReadingTimerSharedKeys.pendingCompletionBlob) != nil)
    }

    @Test @MainActor func appRestartKeepsExternalSessionInsideSafetyWindow() throws {
        let shared = LiveActivitySharedStore.userDefaults
        let standard = UserDefaults.standard
        shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
        shared.removeObject(forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
        standard.removeObject(forKey: ReadingTimerManager.Keys.activeBlob)
        defer {
            shared.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            shared.removeObject(forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
            standard.removeObject(forKey: ReadingTimerManager.Keys.activeBlob)
        }

        standard.set(true, forKey: ReadingTimerManager.Keys.autoStopEnabled)
        standard.set(45, forKey: ReadingTimerManager.Keys.autoStopMinutes)

        let now = Date()
        let bookID = UUID(uuidString: "8A91F526-21CA-41A3-B320-D78148926658")!
        let active = ReadingTimerActiveBlob(
            bookID: bookID,
            bookTitle: "Restart External",
            startedAt: now.addingTimeInterval(-900),
            lastResumedAt: now.addingTimeInterval(-900),
            accumulatedSeconds: 0,
            isPaused: false,
            pausedAt: nil,
            readingMedium: .ebook,
            readingProvider: .kindle,
            progressUnit: .percentage,
            origin: .timer,
            expectedExternalReading: true,
            totalValue: 100,
            lastBackgroundedAt: now.addingTimeInterval(-60 * 60)
        )
        shared.set(try #require(ReadingTimerSharedCodec.encodeActive(active)), forKey: ReadingTimerSharedKeys.activeBlob)

        let manager = ReadingTimerManager()

        let restored = try #require(manager.active)
        #expect(restored.bookID == bookID)
        #expect(restored.expectedExternalReading)
        #expect(restored.progressUnit == .percentage)
        #expect(manager.pendingCompletion == nil)
    }

    private struct LegacyActiveV1: Encodable {
        let bookID: UUID
        let bookTitle: String
        let startedAt: Date
        let lastResumedAt: Date
        let accumulatedSeconds: Int
        let isPaused: Bool
        let pausedAt: Date?
    }

    private struct LegacyActiveV2: Encodable {
        let schemaVersion: Int
        let bookID: UUID
        let bookTitle: String
        let startedAt: Date
        let lastResumedAt: Date
        let accumulatedSeconds: Int
        let isPaused: Bool
        let pausedAt: Date?
        let liveActivitySnapshot: ReadingSessionLiveActivitySnapshot?
    }

    private struct LegacyPendingV1: Encodable {
        let id: UUID
        let bookID: UUID
        let bookTitle: String
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int
        let wasAutoStopped: Bool
        let autoStopMinutes: Int?
    }

    private struct LegacyPendingV2: Encodable {
        let schemaVersion: Int
        let id: UUID
        let bookID: UUID
        let bookTitle: String
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int
        let wasAutoStopped: Bool
        let autoStopMinutes: Int?
    }
}
