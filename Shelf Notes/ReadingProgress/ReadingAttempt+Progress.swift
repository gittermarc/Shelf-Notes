//
//  ReadingAttempt+Progress.swift
//  Shelf Notes
//

import Foundation

@MainActor
extension ReadingAttempt {
    /// Value snapshot used by the format-neutral progress engine.
    var progressInputSnapshot: ReadingProgressAttemptSnapshot {
        let attemptID = id
        let relatedSessions = sessionsSafe.filter { session in
            guard let relatedAttemptID = session.readingAttempt?.id else {
                return true
            }
            return relatedAttemptID == attemptID
        }
        let relatedEvents = progressEventsSafe.filter { event in
            guard let relatedAttemptID = event.readingAttempt?.id else {
                return true
            }
            return relatedAttemptID == attemptID
        }

        var sessionUpdates: [ReadingProgressUpdate] = []
        sessionUpdates.reserveCapacity(relatedSessions.count * 2)
        for session in relatedSessions {
            sessionUpdates.append(contentsOf: ReadingProgressUpdate.updates(session: session))
        }

        var eventUpdates: [ReadingProgressUpdate] = []
        eventUpdates.reserveCapacity(relatedEvents.count)
        for event in relatedEvents {
            eventUpdates.append(ReadingProgressUpdate(event: event))
        }

        return ReadingProgressAttemptSnapshot(
            attemptID: attemptID,
            status: status,
            unit: progressUnit,
            pageCountSnapshot: pageCountSnapshot,
            totalValueSnapshot: totalValueSnapshot,
            sessionPageValues: relatedSessions.compactMap(\.pagesRead),
            updates: sessionUpdates + eventUpdates
        )
    }

    var readingProgressSnapshot: ReadingProgressSnapshot {
        ReadingProgressEngine.snapshot(for: progressInputSnapshot)
    }
}

@MainActor
extension ReadingProgressUpdate {
    static func updates(session: ReadingSession) -> [ReadingProgressUpdate] {
        let stablePrefix = "session:\(session.id.uuidString.lowercased())"
        return [
            ReadingProgressUpdate(
                stableIdentifier: "\(stablePrefix):start",
                occurredAt: session.startedAt,
                unit: session.progressUnit,
                nativeValue: session.startValue,
                totalValue: nil,
                normalizedProgress: session.startNormalizedProgress,
                locator: session.startLocator
            ),
            ReadingProgressUpdate(
                stableIdentifier: "\(stablePrefix):end",
                occurredAt: session.endedAt,
                unit: session.progressUnit,
                nativeValue: session.endValue,
                totalValue: nil,
                normalizedProgress: session.endNormalizedProgress,
                locator: session.endLocator
            )
        ]
    }

    init(event: ReadingProgressEvent) {
        let normalizedKey = event.deduplicationKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stablePrefix = normalizedKey.isEmpty
            ? "event"
            : "event:\(normalizedKey)"

        self.init(
            stableIdentifier: "\(stablePrefix):\(event.id.uuidString.lowercased())",
            occurredAt: event.occurredAt,
            unit: event.progressUnit,
            nativeValue: event.nativeValue,
            totalValue: event.totalValue,
            normalizedProgress: event.normalizedProgress,
            locator: event.locator
        )
    }
}