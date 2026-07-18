//
//  LiveActivitySharedStore.swift
//  Shelf Notes
//
//  Shared utilities for the Reading Session Live Activity.
//  - Shared UserDefaults via App Group
//  - Shared file container for the cover thumbnail
//

import Foundation

nonisolated enum LiveActivitySharedStore {

    /// Must match the App Group enabled for both the app and the widget extension.
    static let appGroupID: String = "group.de.marcfechner.Shelf-Notes"

    static var userDefaults: UserDefaults {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            return defaults
        }
        return .standard
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var coverDirectoryURL: URL? {
        guard let base = appGroupContainerURL else { return nil }
        return base.appendingPathComponent("LiveActivityCovers", isDirectory: true)
    }

    static func coverFileName(bookIDString: String) -> String {
        "la_cover_\(bookIDString).jpg"
    }

    static func bookIDString(fromCoverFileName fileName: String) -> String? {
        guard fileName.hasPrefix("la_cover_"), fileName.hasSuffix(".jpg") else { return nil }
        let withoutPrefix = fileName.dropFirst("la_cover_".count)
        let withoutSuffix = withoutPrefix.dropLast(".jpg".count)
        let candidate = String(withoutSuffix)
        guard UUID(uuidString: candidate) != nil else { return nil }
        return candidate
    }

    static func coverFileURL(bookIDString: String) -> URL? {
        guard let dir = coverDirectoryURL else { return nil }
        return dir.appendingPathComponent(coverFileName(bookIDString: bookIDString), isDirectory: false)
    }

    static func ensureCoverDirectoryExists() {
        guard let dir = coverDirectoryURL else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            // Non-fatal. We simply won't show covers if the directory can't be created.
        }
    }

    static func removeCoverFile(bookIDString: String) {
        guard let url = coverFileURL(bookIDString: bookIDString) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func removeOrphanedCoverFiles(keepingBookIDStrings keepers: Set<String>) {
        guard let directory = coverDirectoryURL else { return }
        let fileNames = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        for fileName in LiveActivityCoverCleanupPolicy.fileNamesToRemove(
            existingFileNames: fileNames,
            keepingBookIDStrings: keepers
        ) {
            let url = directory.appendingPathComponent(fileName, isDirectory: false)
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func togglePauseForActiveSession(
        bookID: UUID,
        now: Date = Date(),
        defaults: UserDefaults = LiveActivitySharedStore.userDefaults
    ) -> ReadingTimerSharedPauseMutationResult {
        switch readSupportedActive(bookID: bookID, defaults: defaults) {
        case .failure(let failure):
            return .failure(failure)
        case .success(var active):
            if active.isPaused {
                active.resume(now: now)
            } else {
                active.pause(now: now)
            }

            guard let encoded = ReadingTimerSharedCodec.encodeActive(active) else {
                return .failure(.encodingFailed)
            }

            defaults.set(encoded, forKey: ReadingTimerSharedKeys.activeBlob)
            return .updated(active)
        }
    }

    static func stopActiveSession(
        bookID: UUID,
        now: Date = Date(),
        pendingID: UUID = UUID(),
        defaults: UserDefaults = LiveActivitySharedStore.userDefaults,
        removeCover: Bool = true
    ) -> ReadingTimerSharedStopMutationResult {
        switch readSupportedActive(bookID: bookID, defaults: defaults) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let active):
            let end = active.isPaused ? (active.pausedAt ?? now) : now
            let duration = active.totalElapsedSeconds(now: end)
            let pending = ReadingTimerPendingCompletionBlob(
                id: pendingID,
                bookID: active.bookID,
                bookTitle: active.bookTitle,
                startedAt: active.startedAt,
                endedAt: end,
                durationSeconds: duration,
                wasAutoStopped: false,
                autoStopMinutes: nil,
                readingAttemptID: active.readingAttemptID,
                readingMedium: active.readingMedium,
                readingProvider: active.readingProvider,
                progressUnit: active.progressUnit,
                origin: active.origin,
                expectedExternalReading: active.expectedExternalReading,
                totalValue: active.totalValue
            )

            guard let pendingData = ReadingTimerSharedCodec.encodePendingCompletion(pending) else {
                return .failure(.encodingFailed)
            }

            defaults.set(pendingData, forKey: ReadingTimerSharedKeys.pendingCompletionBlob)
            defaults.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)

            if removeCover {
                removeCoverFile(bookIDString: bookID.uuidString)
            }

            return .stopped(active: active, pending: pending)
        }
    }

    private static func readSupportedActive(
        bookID: UUID,
        defaults: UserDefaults
    ) -> Result<ReadingTimerActiveBlob, ReadingTimerSharedMutationFailure> {
        let activeData = defaults.data(forKey: ReadingTimerSharedKeys.activeBlob)
        guard let blob = ReadingTimerSharedCodec.decodeActive(from: activeData) else {
            if activeData != nil {
                defaults.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            }
            return .failure(.missingActive)
        }

        guard blob.hasSupportedSchemaVersion else {
            defaults.removeObject(forKey: ReadingTimerSharedKeys.activeBlob)
            return .failure(.unsupportedSchema)
        }

        guard blob.bookID == bookID else {
            return .failure(.mismatchedBookID)
        }

        return .success(blob)
    }
}

nonisolated enum ReadingTimerSharedMutationFailure: Error, Equatable, Sendable {
    case missingActive
    case unsupportedSchema
    case mismatchedBookID
    case encodingFailed
}

nonisolated enum ReadingTimerSharedPauseMutationResult: Equatable, Sendable {
    case updated(ReadingTimerActiveBlob)
    case failure(ReadingTimerSharedMutationFailure)
}

nonisolated enum ReadingTimerSharedStopMutationResult: Equatable, Sendable {
    case stopped(active: ReadingTimerActiveBlob, pending: ReadingTimerPendingCompletionBlob)
    case failure(ReadingTimerSharedMutationFailure)
}

nonisolated enum LiveActivityCoverCleanupPolicy {
    static func fileNamesToRemove(
        existingFileNames: [String],
        keepingBookIDStrings: Set<String>
    ) -> [String] {
        existingFileNames.filter { fileName in
            guard let bookIDString = LiveActivitySharedStore.bookIDString(fromCoverFileName: fileName) else {
                return false
            }
            return !keepingBookIDStrings.contains(bookIDString)
        }
    }
}
