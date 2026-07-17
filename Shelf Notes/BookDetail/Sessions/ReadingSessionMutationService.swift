//
//  ReadingSessionMutationService.swift
//  Shelf Notes
//

import Foundation
import SwiftData

@MainActor
enum ReadingSessionMutationService {
    static func makePlan(
        book: Book,
        allSessions: [ReadingSession],
        timing: ReadingSessionLogging.Timing,
        progressUpdate: ReadingProgressUpdate?,
        note: String?,
        source: ReadingSessionSource,
        mutationMode: ReadingProgressMutationMode = .standard,
        activeAttempt explicitActiveAttempt: ReadingAttempt? = nil,
        replacingSession: ReadingSession? = nil
    ) -> Result<ReadingSessionMutationPlan, ReadingSessionLogging.ValidationError> {
        let activeAttempt = explicitActiveAttempt ?? book.activeReadingAttempt
        let attemptSessions = activeAttempt.map { attempt in
            ReadingAttemptSessionCoordinator.sessions(for: attempt, allSessions: allSessions)
        } ?? allSessions
        let scopedSessions = attemptSessions.filter { $0.id != replacingSession?.id }
        let allowsFinishedBookSupplement = book.status == .finished && activeAttempt == nil
        let context = ReadingSessionContext.resolved(
            readingAttempt: activeAttempt,
            requestedSource: source
        )
        let currentProgress = currentProgressSnapshot(
            book: book,
            attempt: activeAttempt,
            context: context,
            sessions: scopedSessions,
            excludingSessionID: replacingSession?.id
        )

        return ReadingSessionLogging.plan(
            bookState: ReadingSessionLogging.BookState(book: book),
            existingSessions: scopedSessions,
            currentProgress: currentProgress,
            timing: timing,
            progressUpdate: progressUpdate,
            note: note,
            mutationMode: mutationMode,
            allowsFinishedBookSupplement: allowsFinishedBookSupplement
        )
        .map { plan in
            ReadingSessionMutationPlan(
                plan: plan,
                context: context,
                activeAttempt: activeAttempt,
                scopedSessions: scopedSessions,
                currentProgress: currentProgress,
                allowsFinishedBookSupplement: allowsFinishedBookSupplement
            )
        }
    }

    static func makePlan(
        book: Book,
        allSessions: [ReadingSession],
        timing: ReadingSessionLogging.Timing,
        pages: Int?,
        note: String?,
        activeAttempt explicitActiveAttempt: ReadingAttempt? = nil,
        origin: ReadingSessionOrigin = .legacy
    ) -> Result<ReadingSessionMutationPlan, ReadingSessionLogging.ValidationError> {
        let activeAttempt = explicitActiveAttempt ?? book.activeReadingAttempt
        let source = pageSource(
            book: book,
            attempt: activeAttempt,
            origin: origin
        )
        let progressUpdate = ReadingSessionLogging.normalizePages(pages).map {
            ReadingProgressUpdate.pageDelta(
                $0,
                occurredAt: timing.endedAt
            )
        }

        return makePlan(
            book: book,
            allSessions: allSessions,
            timing: timing,
            progressUpdate: progressUpdate,
            note: note,
            source: source,
            activeAttempt: activeAttempt
        )
    }

    static func saveSession(
        book: Book,
        modelContext: ModelContext,
        timing: ReadingSessionLogging.Timing,
        progressUpdate: ReadingProgressUpdate?,
        note: String?,
        source: ReadingSessionSource,
        mutationMode: ReadingProgressMutationMode = .standard,
        allSessions: [ReadingSession],
        now: Date,
        externalEventIdentifier: String? = nil,
        existingSession: ReadingSession? = nil
    ) -> Result<SavedReadingSessionMutationResult, ReadingSessionMutationError> {
        let existingActiveAttempt = book.activeReadingAttempt
        let mutationPlan: ReadingSessionMutationPlan

        switch makePlan(
            book: book,
            allSessions: allSessions,
            timing: timing,
            progressUpdate: progressUpdate,
            note: note,
            source: source,
            mutationMode: mutationMode,
            activeAttempt: existingActiveAttempt,
            replacingSession: existingSession
        ) {
        case .failure(let error):
            return .failure(.validation(error))
        case .success(let plan):
            mutationPlan = plan
        }

        let activeAttempt = ReadingAttemptSessionCoordinator.ensureActiveAttemptForSessionIfNeeded(
            book: book,
            startedAt: timing.startedAt,
            now: now,
            source: source,
            insertAttempt: { modelContext.insert($0) }
        )
        let context = ReadingSessionContext.resolved(
            readingAttempt: activeAttempt,
            requestedSource: source
        )

        mutationPlan.plan.apply(to: book)
        let session = mutationPlan.plan.makeSession(
            book: book,
            context: context,
            existingSession: existingSession
        )
        session.externalEventIdentifier = normalizedIdentifier(externalEventIdentifier)
            ?? existingSession?.externalEventIdentifier

        if existingSession == nil {
            modelContext.insert(session)
        } else if let previousAttempt = session.readingAttempt,
                  previousAttempt.id != activeAttempt?.id {
            ReadingAttemptSessionCoordinator.detachBeforeDeleting(session, now: now)
        }

        ReadingAttemptSessionCoordinator.attach(
            session: session,
            to: activeAttempt,
            plan: mutationPlan.plan,
            book: book,
            now: now
        )

        let progressEvent = ReadingProgressEventMutationService.upsertSessionEvent(
            book: book,
            attempt: activeAttempt,
            session: session,
            context: context,
            progress: mutationPlan.plan.progress,
            modelContext: modelContext,
            now: now
        )

        if let error = modelContext.saveWithDiagnostics() {
            return .failure(.saveFailed(error))
        }

        let snapshot = SavedReadingSessionSnapshot(
            bookID: book.id,
            session: session,
            progressEventID: progressEvent?.id
        )
        return .success(
            SavedReadingSessionMutationResult(
                bookID: book.id,
                session: session,
                progressEvent: progressEvent,
                sessionSnapshot: snapshot,
                progressUpdate: mutationPlan.plan.progress.update,
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

    static func saveSession(
        book: Book,
        modelContext: ModelContext,
        timing: ReadingSessionLogging.Timing,
        pages: Int?,
        note: String?,
        allSessions: [ReadingSession],
        now: Date,
        origin: ReadingSessionOrigin = .legacy,
        externalEventIdentifier: String? = nil,
        existingSession: ReadingSession? = nil
    ) -> Result<SavedReadingSessionMutationResult, ReadingSessionMutationError> {
        let source = pageSource(
            book: book,
            attempt: book.activeReadingAttempt,
            origin: origin
        )
        let update = ReadingSessionLogging.normalizePages(pages).map {
            ReadingProgressUpdate.pageDelta(
                $0,
                occurredAt: timing.endedAt
            )
        }

        return saveSession(
            book: book,
            modelContext: modelContext,
            timing: timing,
            progressUpdate: update,
            note: note,
            source: source,
            allSessions: allSessions,
            now: now,
            externalEventIdentifier: externalEventIdentifier,
            existingSession: existingSession
        )
    }

    private static func pageSource(
        book: Book,
        attempt: ReadingAttempt?,
        origin: ReadingSessionOrigin
    ) -> ReadingSessionSource {
        ReadingSessionSource(
            medium: attempt?.readingMedium ?? .physical,
            provider: attempt?.defaultProvider ?? .none,
            progressUnit: .pages,
            origin: origin,
            totalValue: attempt?.totalValueSnapshot ?? book.pageCount.map(Double.init)
        )
    }

    private static func currentProgressSnapshot(
        book: Book,
        attempt: ReadingAttempt?,
        context: ReadingSessionContext,
        sessions: [ReadingSession],
        excludingSessionID: UUID? = nil
    ) -> ReadingProgressSnapshot {
        if let attempt {
            let attemptID = attempt.id
            let relatedSessionIDs = Set(attempt.sessionsSafe.map(\.id))
            let relatedSessions = sessions.filter { session in
                if let excludingSessionID, session.id == excludingSessionID {
                    return false
                }
                if session.readingAttempt?.id == attemptID {
                    return true
                }
                return relatedSessionIDs.contains(session.id)
            }
            let relatedEvents = attempt.progressEventsSafe.filter { event in
                if let excludingSessionID, event.sourceSessionID == excludingSessionID {
                    return false
                }
                guard let relatedAttemptID = event.readingAttempt?.id else { return true }
                return relatedAttemptID == attemptID
            }
            let fallbackPageCount = attempt.progressUnit == .pages
                ? ReadingAttemptRepair.normalizedPageCount(book.pageCount)
                : nil
            let totalValueSnapshot = attempt.totalValueSnapshot
                ?? context.totalValue
                ?? fallbackPageCount.map(Double.init)
            var updates: [ReadingProgressUpdate] = []
            for session in relatedSessions {
                updates.append(contentsOf: ReadingProgressUpdate.updates(session: session))
            }
            for event in relatedEvents {
                updates.append(ReadingProgressUpdate(event: event))
            }
            return ReadingProgressEngine.snapshot(
                for: ReadingProgressAttemptSnapshot(
                    attemptID: attemptID,
                    status: attempt.status,
                    unit: attempt.progressUnit,
                    pageCountSnapshot: attempt.pageCountSnapshot ?? fallbackPageCount,
                    totalValueSnapshot: totalValueSnapshot,
                    sessionPageValues: relatedSessions.compactMap(\.pagesRead),
                    updates: updates
                )
            )
        }

        return ReadingSessionLogging.progressSnapshot(
            status: book.status,
            unit: context.progressUnit,
            totalPages: context.progressUnit == .pages ? book.pageCount : nil,
            totalValue: context.totalValue,
            sessions: sessions
        )
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }
}
