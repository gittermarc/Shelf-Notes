//
//  ReadingSessionMutationModels.swift
//  Shelf Notes
//

import Foundation

struct ReadingSessionMutationPlan {
    let plan: ReadingSessionLogging.Plan
    let context: ReadingSessionContext
    let activeAttempt: ReadingAttempt?
    let scopedSessions: [ReadingSession]
    let currentProgress: ReadingProgressSnapshot
    let allowsFinishedBookSupplement: Bool
}

struct SavedReadingSessionSnapshot: Equatable, Sendable {
    let id: UUID
    let bookID: UUID
    let readingAttemptID: UUID?
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let pagesRead: Int?
    let note: String?
    let hasNote: Bool
    let medium: ReadingMedium
    let provider: ReadingProvider
    let origin: ReadingSessionOrigin
    let progressUnit: ReadingProgressUnit
    let startValue: Double?
    let endValue: Double?
    let startNormalizedProgress: Double?
    let endNormalizedProgress: Double?
    let startLocator: String?
    let endLocator: String?
    let externalEventIdentifier: String?
    let progressEventID: UUID?

    init(
        id: UUID,
        bookID: UUID,
        readingAttemptID: UUID? = nil,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        pagesRead: Int?,
        note: String?,
        medium: ReadingMedium = .physical,
        provider: ReadingProvider = .none,
        origin: ReadingSessionOrigin = .legacy,
        progressUnit: ReadingProgressUnit = .pages,
        startValue: Double? = nil,
        endValue: Double? = nil,
        startNormalizedProgress: Double? = nil,
        endNormalizedProgress: Double? = nil,
        startLocator: String? = nil,
        endLocator: String? = nil,
        externalEventIdentifier: String? = nil,
        progressEventID: UUID? = nil
    ) {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.bookID = bookID
        self.readingAttemptID = readingAttemptID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = ReadingSessionLogging.normalizePages(pagesRead)
        if let trimmedNote, trimmedNote.isEmpty == false {
            self.note = trimmedNote
        } else {
            self.note = nil
        }
        self.hasNote = self.note != nil
        self.medium = medium
        self.provider = provider
        self.origin = origin
        self.progressUnit = progressUnit
        self.startValue = startValue
        self.endValue = endValue
        self.startNormalizedProgress = startNormalizedProgress
        self.endNormalizedProgress = endNormalizedProgress
        self.startLocator = startLocator
        self.endLocator = endLocator
        self.externalEventIdentifier = externalEventIdentifier
        self.progressEventID = progressEventID
    }

    @MainActor
    init(
        bookID: UUID,
        session: ReadingSession,
        progressEventID: UUID? = nil
    ) {
        self.init(
            id: session.id,
            bookID: bookID,
            readingAttemptID: session.readingAttempt?.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            durationSeconds: session.durationSeconds,
            pagesRead: session.pagesRead,
            note: session.note,
            medium: session.medium,
            provider: session.provider,
            origin: session.origin,
            progressUnit: session.progressUnit,
            startValue: session.startValue,
            endValue: session.endValue,
            startNormalizedProgress: session.startNormalizedProgress,
            endNormalizedProgress: session.endNormalizedProgress,
            startLocator: session.startLocator,
            endLocator: session.endLocator,
            externalEventIdentifier: session.externalEventIdentifier,
            progressEventID: progressEventID
        )
    }
}

struct SavedReadingSessionMutationResult {
    let bookID: UUID
    let session: ReadingSession
    let progressEvent: ReadingProgressEvent?
    let sessionSnapshot: SavedReadingSessionSnapshot
    let progressUpdate: ReadingProgressUpdate?
    let didMarkBookFinished: Bool
    let didImplyReading: Bool
    let isLegacySupplement: Bool
    let hasNote: Bool
    let pagesRead: Int?
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
}

enum ReadingSessionMutationError: Error {
    case validation(ReadingSessionLogging.ValidationError)
    case saveFailed(Error)

    var message: String {
        switch self {
        case .validation(let error):
            return error.message
        case .saveFailed(let error):
            return "Konnte Session nicht speichern: " + error.localizedDescription
        }
    }
}
