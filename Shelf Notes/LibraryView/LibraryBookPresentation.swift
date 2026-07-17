//
//  LibraryBookPresentation.swift
//  Shelf Notes
//
//  Prepared value-only display data for library rows and grid cards.
//

import Foundation

nonisolated struct LibraryBookPresentation: Equatable {
    let id: UUID
    let progressFraction: Double?
    let progressText: String?
    let pageProgressText: String?
    let remainingPagesText: String?
    let detailText: String?
    let sourceText: String?
    let rereadBadgeText: String?
    let lastActivityText: String?
    let shouldShowReadingProgress: Bool

    init(snapshot: LibraryView.LibrarySourceSnapshot.BookSnapshot) {
        let progressUnit = ReadingProgressUnit.fromPersisted(snapshot.progressUnitRawValue)
        let medium = ReadingMedium.fromPersisted(snapshot.readingMediumRawValue)
        let provider = ReadingProvider.fromPersisted(snapshot.readingProviderRawValue)
        let normalizedProgress = Self.normalizedFraction(snapshot.readingProgressFraction)
        let progressSnapshot = ReadingProgressSnapshot(
            unit: progressUnit,
            nativeValue: snapshot.progressNativeValue,
            totalValue: snapshot.progressTotalValue,
            pagesRead: progressUnit == .pages ? snapshot.pagesReadTotal : nil,
            remainingPages: Self.remainingPages(
                pagesReadTotal: snapshot.pagesReadTotal,
                totalValue: snapshot.progressTotalValue,
                progressUnit: progressUnit
            ),
            normalizedProgress: normalizedProgress,
            locator: snapshot.progressLocator,
            isCompleted: snapshot.status == .finished
        )
        let adaptive = ReadingProgressPresentationBuilder.make(
            snapshot: progressSnapshot,
            medium: medium,
            provider: provider,
            status: snapshot.status
        )
        let pages: (progress: String?, remaining: String?)
        if progressUnit == .pages {
            pages = Self.pageTexts(
                pagesReadTotal: snapshot.pagesReadTotal,
                totalValue: snapshot.progressTotalValue
            )
        } else {
            pages = (progress: nil, remaining: nil)
        }
        let metricContribution = ReadingProgressMetricMapper.contribution(from: progressSnapshot)

        id = snapshot.id
        progressFraction = normalizedProgress
        progressText = normalizedProgress.map(Self.progressText)
        pageProgressText = pages.progress
        remainingPagesText = pages.remaining
        detailText = progressUnit == .pages ? nil : adaptive.detailText
        sourceText = medium == .physical && provider == .none && progressUnit == .pages
            ? nil
            : adaptive.source.title
        rereadBadgeText = Self.rereadBadgeText(for: snapshot)
        lastActivityText = Self.lastActivityText(for: snapshot.lastSessionAt)
        shouldShowReadingProgress = snapshot.status == .reading && metricContribution.hasMeasuredProgress
    }

    init(
        id: UUID,
        progressFraction: Double?,
        progressText: String?,
        pageProgressText: String?,
        remainingPagesText: String?,
        detailText: String? = nil,
        sourceText: String? = nil,
        rereadBadgeText: String?,
        lastActivityText: String?,
        shouldShowReadingProgress: Bool
    ) {
        self.id = id
        self.progressFraction = Self.normalizedFraction(progressFraction)
        self.progressText = progressText
        self.pageProgressText = pageProgressText
        self.remainingPagesText = remainingPagesText
        self.detailText = detailText
        self.sourceText = sourceText
        self.rereadBadgeText = rereadBadgeText
        self.lastActivityText = lastActivityText
        self.shouldShowReadingProgress = shouldShowReadingProgress
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

        if let detailText {
            parts.append(detailText)
        }

        if let sourceText {
            parts.append(sourceText)
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
        totalValue: Double?
    ) -> (progress: String?, remaining: String?) {
        guard let pageCount = positiveIntegral(totalValue) else {
            let readPages = max(0, pagesReadTotal)
            let unit = readPages == 1 ? "Seite" : "Seiten"
            return readPages > 0 ? ("\(readPages) \(unit) gelesen", nil) : (nil, nil)
        }

        let readPages = min(max(0, pagesReadTotal), pageCount)
        let remainingPages = max(0, pageCount - readPages)
        let progress = "\(readPages) von \(pageCount) Seiten"
        let remainingUnit = remainingPages == 1 ? "Seite" : "Seiten"
        let remaining = remainingPages > 0 ? "noch \(remainingPages) \(remainingUnit)" : nil
        return (progress, remaining)
    }

    private static func remainingPages(
        pagesReadTotal: Int,
        totalValue: Double?,
        progressUnit: ReadingProgressUnit
    ) -> Int? {
        guard progressUnit == .pages,
              let total = positiveIntegral(totalValue) else {
            return nil
        }
        return max(0, total - min(max(0, pagesReadTotal), total))
    }

    private static func positiveIntegral(_ value: Double?) -> Int? {
        guard let value,
              value.isFinite,
              value > 0,
              value <= Double(Int.max),
              value.rounded(.towardZero) == value else {
            return nil
        }
        return Int(value)
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
