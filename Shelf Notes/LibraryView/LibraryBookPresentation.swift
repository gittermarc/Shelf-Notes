//
//  LibraryBookPresentation.swift
//  Shelf Notes
//
//  Prepared value-only display data for library rows and grid cards.
//

import Foundation

struct LibraryBookPresentation: Equatable {
    let id: UUID
    let progressFraction: Double?
    let progressText: String?
    let pageProgressText: String?
    let remainingPagesText: String?
    let rereadBadgeText: String?
    let lastActivityText: String?
    let shouldShowReadingProgress: Bool

    init(snapshot: LibraryView.LibrarySourceSnapshot.BookSnapshot) {
        let normalizedProgress = Self.normalizedFraction(snapshot.readingProgressFraction)
        let pages = Self.pageTexts(
            pagesReadTotal: snapshot.pagesReadTotal,
            pageCount: snapshot.pageCount
        )

        id = snapshot.id
        progressFraction = normalizedProgress
        progressText = normalizedProgress.map(Self.progressText)
        pageProgressText = pages.progress
        remainingPagesText = pages.remaining
        rereadBadgeText = Self.rereadBadgeText(for: snapshot)
        lastActivityText = Self.lastActivityText(for: snapshot.lastSessionAt)
        shouldShowReadingProgress = snapshot.status == .reading && normalizedProgress != nil
    }

    init(
        id: UUID,
        progressFraction: Double?,
        progressText: String?,
        pageProgressText: String?,
        remainingPagesText: String?,
        rereadBadgeText: String?,
        lastActivityText: String?,
        shouldShowReadingProgress: Bool
    ) {
        self.id = id
        self.progressFraction = Self.normalizedFraction(progressFraction)
        self.progressText = progressText
        self.pageProgressText = pageProgressText
        self.remainingPagesText = remainingPagesText
        self.rereadBadgeText = rereadBadgeText
        self.lastActivityText = lastActivityText
        self.shouldShowReadingProgress = shouldShowReadingProgress && Self.normalizedFraction(progressFraction) != nil
    }

    var accessibilitySummary: String {
        var parts: [String] = []

        if let progressText {
            parts.append("Lesefortschritt \(progressText)")
        }

        if let pageProgressText {
            parts.append(pageProgressText)
        }

        if let remainingPagesText {
            parts.append(remainingPagesText)
        }

        if let rereadBadgeText {
            parts.append(rereadBadgeText)
        }

        return parts.joined(separator: ", ")
    }

    private static func normalizedFraction(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(1.0, max(0.0, value))
    }

    private static func progressText(_ fraction: Double) -> String {
        let percent = Int((fraction * 100).rounded())
        return "\(percent) %"
    }

    private static func pageTexts(
        pagesReadTotal: Int,
        pageCount: Int?
    ) -> (progress: String?, remaining: String?) {
        guard let pageCount, pageCount > 0 else {
            return (nil, nil)
        }

        let readPages = min(max(0, pagesReadTotal), pageCount)
        let remainingPages = max(0, pageCount - readPages)
        let progress = "\(readPages) von \(pageCount) Seiten"
        let remainingUnit = remainingPages == 1 ? "Seite" : "Seiten"
        let remaining = remainingPages > 0 ? "noch \(remainingPages) \(remainingUnit)" : nil
        return (progress, remaining)
    }

    private static func rereadBadgeText(for snapshot: LibraryView.LibrarySourceSnapshot.BookSnapshot) -> String? {
        guard snapshot.isRereading else { return nil }

        let trimmed = snapshot.currentReadingAttemptDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmed, trimmed.isEmpty == false {
            return trimmed
        }

        if snapshot.completedReadingAttemptCount > 0 {
            return "\(snapshot.completedReadingAttemptCount + 1). Durchgang"
        }

        return "Re-Read"
    }

    private static func lastActivityText(for date: Date?) -> String? {
        guard let date else { return nil }
        return "zuletzt \(date.formatted(.dateTime.day().month(.abbreviated).year()))"
    }
}
