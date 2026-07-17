//
//  ReadingProgressImportMutationService.swift
//  Shelf Notes
//

import Foundation
import SwiftData

nonisolated struct ReadingProgressImportRequest: Equatable, Sendable {
    let update: ReadingProgressUpdate
    let source: ReadingSessionSource
    let externalIdentifier: String?
    let deduplicationKey: String
    let importedAt: Date
    let mutationMode: ReadingProgressMutationMode

    init(
        update: ReadingProgressUpdate,
        source: ReadingSessionSource,
        externalIdentifier: String? = nil,
        deduplicationKey: String,
        importedAt: Date,
        mutationMode: ReadingProgressMutationMode = .standard
    ) {
        self.update = update
        self.source = source
        self.externalIdentifier = externalIdentifier
        self.deduplicationKey = deduplicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.importedAt = importedAt
        self.mutationMode = mutationMode
    }
}

struct SavedReadingProgressEventSnapshot: Equatable, Sendable {
    let id: UUID
    let bookID: UUID
    let readingAttemptID: UUID?
    let occurredAt: Date
    let medium: ReadingMedium
    let provider: ReadingProvider
    let progressUnit: ReadingProgressUnit
    let nativeValue: Double
    let totalValue: Double?
    let normalizedProgress: Double?
    let locator: String?
    let origin: ReadingSessionOrigin
    let externalIdentifier: String?
    let deduplicationKey: String
    let sourceSessionID: UUID?
}

struct SavedReadingProgressImportResult {
    let event: ReadingProgressEvent
    let snapshot: SavedReadingProgressEventSnapshot
    let didMarkBookFinished: Bool
    let didImplyReading: Bool
}

enum ReadingProgressImportMutationError: Error {
    case invalidDeduplicationKey
    case validation(ReadingProgressMutationValidationError)
    case saveFailed(Error)

    var message: String {
        switch self {
        case .invalidDeduplicationKey:
            return "Der Fortschrittsimport benötigt einen stabilen Deduplizierungsschlüssel."
        case .validation(let error):
            return error.message
        case .saveFailed(let error):
            return "Konnte Fortschritt nicht speichern: " + error.localizedDescription
        }
    }
}

@MainActor
enum ReadingProgressImportMutationService {
    static func saveProgress(
        book: Book,
        modelContext: ModelContext,
        request: ReadingProgressImportRequest,
        allSessions: [ReadingSession],
        now: Date
    ) -> Result<SavedReadingProgressImportResult, ReadingProgressImportMutationError> {
        guard request.deduplicationKey.isEmpty == false else {
            return .failure(.invalidDeduplicationKey)
        }

        let activeAttempt = book.activeReadingAttempt
        let scopedSessions = activeAttempt.map {
            ReadingAttemptSessionCoordinator.sessions(for: $0, allSessions: allSessions)
        } ?? allSessions
        let currentProgress = currentProgressSnapshot(
            book: book,
            attempt: activeAttempt,
            source: request.source,
            sessions: scopedSessions
        )

        let progressResult = ReadingProgressMutationPlanner.makePlan(
            current: currentProgress,
            update: request.update,
            mode: request.mutationMode,
            allowsPageOverflow: false,
            allowsAbsolutePageValue: true
        )

        let progress: ReadingProgressMutationPlan
        switch progressResult {
        case .success(let value):
            progress = value
        case .failure(let error):
            return .failure(.validation(error))
        }

        let timing = ReadingSessionLogging.Timing(
            startedAt: request.update.occurredAt,
            endedAt: request.update.occurredAt
        )
        let loggingResult = ReadingSessionLogging.plan(
            bookState: ReadingSessionLogging.BookState(book: book),
            existingSessions: scopedSessions,
            currentProgress: currentProgress,
            timing: timing,
            progressUpdate: request.update,
            note: nil,
            mutationMode: request.mutationMode,
            allowsFinishedBookSupplement: false,
            allowsAbsolutePageValue: true
        )

        let loggingPlan: ReadingSessionLogging.Plan
        switch loggingResult {
        case .success(let value):
            loggingPlan = value
        case .failure(let error):
            return .failure(.validation(error))
        }

        let attempt = ReadingAttemptSessionCoordinator.ensureActiveAttemptForSessionIfNeeded(
            book: book,
            startedAt: request.update.occurredAt,
            now: now,
            source: request.source,
            insertAttempt: { modelContext.insert($0) }
        )

        let existingReadFrom = book.readFrom
        let existingReadTo = book.readTo
        loggingPlan.apply(to: book)
        book.readFrom = existingReadFrom
        book.readTo = existingReadTo
        ReadingAttemptSessionCoordinator.applyProgressMutation(
            to: attempt,
            plan: loggingPlan,
            book: book,
            now: now
        )

        let event = ReadingProgressEventMutationService.upsertImportedEvent(
            book: book,
            attempt: attempt,
            request: request,
            progress: progress,
            modelContext: modelContext,
            now: now
        )

        if let error = modelContext.saveWithDiagnostics() {
            return .failure(.saveFailed(error))
        }

        return .success(
            SavedReadingProgressImportResult(
                event: event,
                snapshot: snapshot(bookID: book.id, event: event),
                didMarkBookFinished: loggingPlan.didMarkFinished,
                didImplyReading: loggingPlan.didImplyReading
            )
        )
    }

    private static func currentProgressSnapshot(
        book: Book,
        attempt: ReadingAttempt?,
        source: ReadingSessionSource,
        sessions: [ReadingSession]
    ) -> ReadingProgressSnapshot {
        if let attempt {
            return attempt.readingProgressSnapshot
        }

        return ReadingSessionLogging.progressSnapshot(
            status: book.status,
            unit: source.progressUnit,
            totalPages: source.progressUnit == .pages ? book.pageCount : nil,
            totalValue: source.totalValue,
            sessions: sessions
        )
    }

    private static func snapshot(
        bookID: UUID,
        event: ReadingProgressEvent
    ) -> SavedReadingProgressEventSnapshot {
        SavedReadingProgressEventSnapshot(
            id: event.id,
            bookID: bookID,
            readingAttemptID: event.readingAttempt?.id,
            occurredAt: event.occurredAt,
            medium: event.medium,
            provider: event.provider,
            progressUnit: event.progressUnit,
            nativeValue: event.nativeValue,
            totalValue: event.totalValue,
            normalizedProgress: event.normalizedProgress,
            locator: event.locator,
            origin: event.origin,
            externalIdentifier: event.externalIdentifier,
            deduplicationKey: event.deduplicationKey,
            sourceSessionID: event.sourceSessionID
        )
    }
}
