//
//  ReadingSessionMutationService.swift
//  Shelf Notes
//

import Foundation
import SwiftData

struct ReadingSessionMutationPlan {
    let plan: ReadingSessionLogging.Plan
    let activeAttempt: ReadingAttempt?
    let scopedSessions: [ReadingSession]
    let allowsFinishedBookSupplement: Bool
}

struct SavedReadingSessionSnapshot: Equatable, Sendable {
    let id: UUID
    let bookID: UUID
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let pagesRead: Int?
    let note: String?
    let hasNote: Bool

    init(
        id: UUID,
        bookID: UUID,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        pagesRead: Int?,
        note: String?
    ) {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.bookID = bookID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = ReadingSessionLogging.normalizePages(pagesRead)
        if let trimmedNote, !trimmedNote.isEmpty {
            self.note = trimmedNote
        } else {
            self.note = nil
        }
        self.hasNote = self.note != nil
    }

    init(bookID: UUID, session: ReadingSession) {
        self.init(
            id: session.id,
            bookID: bookID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            durationSeconds: session.durationSeconds,
            pagesRead: session.pagesRead,
            note: session.note
        )
    }
}

struct SavedReadingSessionMutationResult {
    let bookID: UUID
    let session: ReadingSession
    let sessionSnapshot: SavedReadingSessionSnapshot
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

@MainActor
enum ReadingSessionMutationService {
    static func makePlan(
        book: Book,
        allSessions: [ReadingSession],
        timing: ReadingSessionLogging.Timing,
        pages: Int?,
        note: String?,
        activeAttempt explicitActiveAttempt: ReadingAttempt? = nil
    ) -> Result<ReadingSessionMutationPlan, ReadingSessionLogging.ValidationError> {
        let activeAttempt = explicitActiveAttempt ?? book.activeReadingAttempt
        let scopedSessions = activeAttempt.map { attempt in
            ReadingAttemptSessionCoordinator.sessions(for: attempt, allSessions: allSessions)
        } ?? allSessions
        let allowsFinishedBookSupplement = book.status == .finished && activeAttempt == nil

        return ReadingSessionLogging.plan(
            bookState: ReadingSessionLogging.BookState(book: book),
            existingSessions: scopedSessions,
            timing: timing,
            pages: pages,
            note: note,
            allowsFinishedBookSupplement: allowsFinishedBookSupplement
        )
        .map { plan in
            ReadingSessionMutationPlan(
                plan: plan,
                activeAttempt: activeAttempt,
                scopedSessions: scopedSessions,
                allowsFinishedBookSupplement: allowsFinishedBookSupplement
            )
        }
    }

    static func saveSession(
        book: Book,
        modelContext: ModelContext,
        timing: ReadingSessionLogging.Timing,
        pages: Int?,
        note: String?,
        allSessions: [ReadingSession],
        now: Date
    ) -> Result<SavedReadingSessionMutationResult, ReadingSessionMutationError> {
        let activeAttempt = ReadingAttemptSessionCoordinator.ensureActiveAttemptForSessionIfNeeded(
            book: book,
            startedAt: timing.startedAt,
            now: now,
            insertAttempt: { modelContext.insert($0) }
        )

        let mutationPlan: ReadingSessionMutationPlan
        switch makePlan(
            book: book,
            allSessions: allSessions,
            timing: timing,
            pages: pages,
            note: note,
            activeAttempt: activeAttempt
        ) {
        case .failure(let error):
            return .failure(.validation(error))
        case .success(let plan):
            mutationPlan = plan
        }

        mutationPlan.plan.apply(to: book)
        let session = mutationPlan.plan.makeSession(book: book)
        modelContext.insert(session)

        ReadingAttemptSessionCoordinator.attach(
            session: session,
            to: mutationPlan.activeAttempt,
            plan: mutationPlan.plan,
            book: book,
            now: now
        )

        if let error = modelContext.saveWithDiagnostics() {
            return .failure(.saveFailed(error))
        }

        let snapshot = SavedReadingSessionSnapshot(bookID: book.id, session: session)
        return .success(
            SavedReadingSessionMutationResult(
                bookID: book.id,
                session: session,
                sessionSnapshot: snapshot,
                didMarkBookFinished: mutationPlan.plan.didMarkFinished,
                didImplyReading: mutationPlan.plan.didImplyReading,
                isLegacySupplement: mutationPlan.plan.isLegacySupplement,
                hasNote: snapshot.hasNote,
                pagesRead: snapshot.pagesRead,
                startedAt: snapshot.startedAt,
                endedAt: snapshot.endedAt,
                durationSeconds: snapshot.durationSeconds
            )
        )
    }
}
