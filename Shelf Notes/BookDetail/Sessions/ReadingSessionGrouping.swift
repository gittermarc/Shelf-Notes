//
//  ReadingSessionGrouping.swift
//  Shelf Notes
//

import Foundation

struct ReadingSessionGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let sessions: [ReadingSession]
}

@MainActor
enum ReadingSessionGrouping {

    static func makeGroups(book: Book, sessions: [ReadingSession]) -> [ReadingSessionGroup] {
        let sortedSessions = sessions.sorted(by: newestFirst)
        let attempts = book.orderedReadingAttempts
        let attemptsByPriority = attempts.sorted(by: attemptPriority)
        var usedSessionIDs = Set<UUID>()
        var groups: [ReadingSessionGroup] = []

        for attempt in attemptsByPriority {
            let attemptSessions = sessionsForAttempt(
                attempt,
                from: sortedSessions,
                usedSessionIDs: &usedSessionIDs
            )
            guard attemptSessions.isEmpty == false else { continue }

            groups.append(
                ReadingSessionGroup(
                    id: "attempt-\(attempt.id.uuidString)",
                    title: title(for: attempt),
                    subtitle: subtitle(for: attempt, sessionCount: attemptSessions.count),
                    sessions: attemptSessions
                )
            )
        }

        let legacySessions = sortedSessions.filter { session in
            usedSessionIDs.contains(session.id) == false
        }

        if legacySessions.isEmpty == false {
            groups.append(
                ReadingSessionGroup(
                    id: "legacy-unassigned",
                    title: "Nicht zugeordnet",
                    subtitle: "Legacy-Sessions ohne Lesedurchgang",
                    sessions: legacySessions
                )
            )
        }

        return groups
    }

    static func limitedGroups(_ groups: [ReadingSessionGroup], limit: Int) -> [ReadingSessionGroup] {
        guard limit > 0 else { return [] }

        var remaining = limit
        var output: [ReadingSessionGroup] = []

        for group in groups {
            guard remaining > 0 else { break }
            let limitedSessions = Array(group.sessions.prefix(remaining))
            guard limitedSessions.isEmpty == false else { continue }
            output.append(
                ReadingSessionGroup(
                    id: group.id,
                    title: group.title,
                    subtitle: group.subtitle,
                    sessions: limitedSessions
                )
            )
            remaining -= limitedSessions.count
        }

        return output
    }

    private static func sessionsForAttempt(
        _ attempt: ReadingAttempt,
        from sortedSessions: [ReadingSession],
        usedSessionIDs: inout Set<UUID>
    ) -> [ReadingSession] {
        let attemptID = attempt.id
        let explicitSessionIDs = Set(attempt.sessionsSafe.map(\.id))
        var result: [ReadingSession] = []

        for session in sortedSessions {
            guard usedSessionIDs.contains(session.id) == false else { continue }

            let belongsToAttempt = session.readingAttempt?.id == attemptID || explicitSessionIDs.contains(session.id)
            guard belongsToAttempt else { continue }

            result.append(session)
            usedSessionIDs.insert(session.id)
        }

        return result
    }

    private static func newestFirst(_ left: ReadingSession, _ right: ReadingSession) -> Bool {
        if left.startedAt != right.startedAt {
            return left.startedAt > right.startedAt
        }
        if left.createdAt != right.createdAt {
            return left.createdAt > right.createdAt
        }
        return left.id.uuidString < right.id.uuidString
    }

    private static func attemptPriority(_ left: ReadingAttempt, _ right: ReadingAttempt) -> Bool {
        if left.status == .active, right.status != .active {
            return true
        }
        if left.status != .active, right.status == .active {
            return false
        }
        if left.sequenceNumber != right.sequenceNumber {
            return left.sequenceNumber > right.sequenceNumber
        }
        if left.createdAt != right.createdAt {
            return left.createdAt > right.createdAt
        }
        return left.id.uuidString < right.id.uuidString
    }

    private static func title(for attempt: ReadingAttempt) -> String {
        if attempt.status == .active {
            return attempt.displayName + " · läuft"
        }
        return attempt.displayName
    }

    private static func subtitle(for attempt: ReadingAttempt, sessionCount: Int) -> String? {
        let countText = sessionCount == 1 ? "1 Session" : "\(sessionCount) Sessions"

        switch attempt.status {
        case .active:
            if let startedAt = attempt.startedAt {
                return countText + " · seit " + shortDateFormatter.string(from: startedAt)
            }
            return countText
        case .finished:
            if let finishedAt = attempt.finishedAt {
                return countText + " · abgeschlossen " + shortDateFormatter.string(from: finishedAt)
            }
            return countText + " · abgeschlossen"
        case .abandoned:
            return countText + " · abgebrochen"
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
