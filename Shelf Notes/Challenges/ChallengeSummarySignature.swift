//
//  ChallengeSummarySignature.swift
//  Shelf Notes
//

import Foundation

struct ChallengeSummarySignature: Hashable, Sendable {
    private let entries: [Entry]

    init(challenges: [ChallengeRecord]) {
        self.entries = challenges
            .map(Entry.init(record:))
            .sorted()
    }
}

private extension ChallengeSummarySignature {
    struct Entry: Hashable, Sendable, Comparable {
        let id: UUID
        let kindRawValue: String
        let metricRawValue: String
        let periodStart: Date
        let periodEnd: Date
        let completedAt: Date?
        let acknowledgedAt: Date?
        let targetValue: Int
        let title: String
        let detail: String
        let rerollsUsed: Int
        let rerolledAt: Date?

        init(record: ChallengeRecord) {
            self.id = record.id
            self.kindRawValue = record.kindRawValue
            self.metricRawValue = record.metricRawValue
            self.periodStart = record.periodStart
            self.periodEnd = record.periodEnd
            self.completedAt = record.completedAt
            self.acknowledgedAt = record.acknowledgedAt
            self.targetValue = record.targetValue
            self.title = record.title
            self.detail = record.detail
            self.rerollsUsed = record.rerollsUsed
            self.rerolledAt = record.rerolledAt
        }

        static func < (lhs: Entry, rhs: Entry) -> Bool {
            lhs.sortKey < rhs.sortKey
        }

        private var sortKey: String {
            [
                id.uuidString,
                kindRawValue,
                metricRawValue,
                timestamp(periodStart),
                timestamp(periodEnd),
                optionalTimestamp(completedAt),
                optionalTimestamp(acknowledgedAt),
                String(targetValue),
                title,
                detail,
                String(rerollsUsed),
                optionalTimestamp(rerolledAt)
            ].joined(separator: "\u{1F}")
        }

        private func timestamp(_ date: Date) -> String {
            String(date.timeIntervalSinceReferenceDate)
        }

        private func optionalTimestamp(_ date: Date?) -> String {
            guard let date else { return "nil" }
            return timestamp(date)
        }
    }
}
