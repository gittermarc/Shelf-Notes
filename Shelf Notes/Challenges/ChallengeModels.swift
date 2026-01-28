//
//  ChallengeModels.swift
//  Shelf Notes
//
//  Challenges are stored as records per period (week/month).
//  Progress is computed from ReadingSession + finished books.
//

import Foundation
import SwiftData

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:
            return "Woche"
        case .monthly:
            return "Monat"
        }
    }

    var badgeSystemImage: String {
        switch self {
        case .weekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar"
        }
    }
}

enum ChallengeMetric: String, Codable, CaseIterable, Identifiable {
    case readingMinutes
    case readingDays
    case sessions
    case pagesRead
    case booksFinished

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .readingMinutes:
            return "clock"
        case .readingDays:
            return "flame"
        case .sessions:
            return "timer"
        case .pagesRead:
            return "doc.plaintext"
        case .booksFinished:
            return "checkmark.seal"
        }
    }

    var unitSuffix: String {
        switch self {
        case .readingMinutes:
            return "min"
        case .readingDays:
            return "Tage"
        case .sessions:
            return "Sessions"
        case .pagesRead:
            return "Seiten"
        case .booksFinished:
            return "Bücher"
        }
    }
}

/// A persisted challenge for a concrete period.
///
/// Notes:
/// - No `@Attribute(.unique)` because CloudKit + SwiftData.
/// - `title`/`detail` are persisted so future text tweaks won't break old history.
/// - Progress is computed (and completion can be auto-marked) via `ChallengeEngine`.
@Model
final class ChallengeRecord {
    // CloudKit/SwiftData: avoid @Attribute(.unique)
    var id: UUID = UUID()

    // Period
    // CloudKit requires non-optional attributes to have a default value.
    // Use constant defaults so the Core Data model can be created/migrated safely.
    var periodStart: Date = Date(timeIntervalSince1970: 0)
    var periodEnd: Date = Date(timeIntervalSince1970: 0)

    // Type
    var kindRawValue: String = ChallengeKind.weekly.rawValue
    var metricRawValue: String = ChallengeMetric.readingMinutes.rawValue

    // Content
    var title: String = ""
    var detail: String = ""

    // Target
    var targetValue: Int = 0

    // Meta
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var completedAt: Date?
    var acknowledgedAt: Date?

    /// Simple fun: allow one reroll per period.
    var rerollsUsed: Int = 0
    var rerolledAt: Date?

    init(
        kind: ChallengeKind,
        metric: ChallengeMetric,
        periodStart: Date,
        periodEnd: Date,
        title: String,
        detail: String,
        targetValue: Int
    ) {
        self.kindRawValue = kind.rawValue
        self.metricRawValue = metric.rawValue
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.title = title
        self.detail = detail
        self.targetValue = targetValue
        self.createdAt = Date()
        self.completedAt = nil
        self.acknowledgedAt = nil
        self.rerollsUsed = 0
        self.rerolledAt = nil
    }
}

extension ChallengeRecord {
    var kind: ChallengeKind {
        get { ChallengeKind(rawValue: kindRawValue) ?? .weekly }
        set { kindRawValue = newValue.rawValue }
    }

    var metric: ChallengeMetric {
        get { ChallengeMetric(rawValue: metricRawValue) ?? .readingMinutes }
        set { metricRawValue = newValue.rawValue }
    }

    var isActive: Bool {
        let now = Date()
        return now >= periodStart && now < periodEnd
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var isClaimed: Bool {
        acknowledgedAt != nil
    }

    var canReroll: Bool {
        !isCompleted && rerollsUsed < 1
    }

    var periodLabel: String {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .short
        df.timeStyle = .none

        let start = df.string(from: periodStart)
        let end = df.string(from: Calendar.current.date(byAdding: .day, value: -1, to: periodEnd) ?? periodEnd)
        return "\(start)–\(end)"
    }
}
