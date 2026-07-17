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

    private var progress: ReadingProgressPresentation {
        ReadingProgressPresentationBuilder.make(
            snapshot: attempt.readingProgressSnapshot,
            medium: attempt.readingMedium,
            provider: attempt.defaultProvider,
            status: attempt.status == .finished ? .finished : .reading
        )
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

                Label(progress.source.title, systemImage: progress.source.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let progressValue = progress.normalizedProgress {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                }

                Text(progress.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let supportingText = progress.supportingText {
                    Text(supportingText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(attempt.displayName), \(progress.source.title)")
        .accessibilityValue("\(statusText), \(progress.accessibilityValue)")
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
