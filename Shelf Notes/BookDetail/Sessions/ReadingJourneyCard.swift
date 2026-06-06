//
//  ReadingJourneyCard.swift
//  Shelf Notes
//

import SwiftUI

struct ReadingJourneyCard: View {
    let book: Book

    private var attempts: [ReadingAttempt] {
        book.orderedReadingAttempts
    }

    var body: some View {
        BookDetailCard(title: "Lesebiografie") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(attempts, id: \.id) { attempt in
                    ReadingJourneyAttemptRow(book: book, attempt: attempt)

                    if attempt.id != attempts.last?.id {
                        Divider().opacity(0.45)
                    }
                }
            }
        }
    }
}

private struct ReadingJourneyAttemptRow: View {
    let book: Book
    let attempt: ReadingAttempt

    private var sessions: [ReadingSession] {
        attempt.sessionsSafe.sorted { left, right in
            if left.startedAt != right.startedAt {
                return left.startedAt < right.startedAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private var totalPages: Int? {
        ReadingSessionLogging.normalizedTotalPages(attempt.pageCountSnapshot ?? book.pageCount)
    }

    private var pagesRead: Int {
        ReadingSessionLogging.pagesReadTotal(in: sessions)
    }

    private var progressFraction: Double? {
        if attempt.status == .finished { return 1.0 }
        guard let totalPages else { return nil }
        return min(1.0, max(0.0, Double(max(0, pagesRead)) / Double(totalPages)))
    }

    private var statusText: String {
        switch attempt.status {
        case .active:
            if let startedAt = attempt.startedAt {
                return "läuft seit " + Self.dateFormatter.string(from: startedAt)
            }
            return "läuft"
        case .finished:
            if let start = attempt.startedAt, let end = attempt.finishedAt {
                return Self.dateFormatter.string(from: start) + " – " + Self.dateFormatter.string(from: end)
            }
            if let end = attempt.finishedAt {
                return "abgeschlossen am " + Self.dateFormatter.string(from: end)
            }
            return "abgeschlossen"
        case .abandoned:
            if let start = attempt.startedAt {
                return "abgebrochen · seit " + Self.dateFormatter.string(from: start)
            }
            return "abgebrochen"
        }
    }

    private var progressText: String {
        if attempt.status == .finished {
            if let totalPages {
                return "100 % · \(totalPages) Seiten"
            }
            return "100 %"
        }

        if let totalPages {
            let clampedRead = min(max(0, pagesRead), totalPages)
            let remaining = max(0, totalPages - clampedRead)
            let percent = Int((Double(clampedRead) / Double(totalPages) * 100.0).rounded())
            return "\(percent) % · noch \(remaining) Seiten"
        }

        if pagesRead > 0 {
            return "\(pagesRead) Seiten geloggt"
        }

        return "Noch keine Seiten geloggt"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(attempt.status == .active ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(attempt.status == .active ? Color.green : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(attempt.displayName)
                        .font(.subheadline.weight(.semibold))

                    Text(attempt.status.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(attempt.status == .active ? Color.green : Color.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let progressFraction {
                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)
                }

                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch attempt.status {
        case .active:
            return "book.pages.fill"
        case .finished:
            return "checkmark"
        case .abandoned:
            return "xmark"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
