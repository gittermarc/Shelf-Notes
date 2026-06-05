import SwiftUI

struct CollectionCardView: View {
    let entry: CollectionsDashboardEntry
    let coverBooks: [Book]

    private var subtitle: String {
        if entry.bookCount == 0 {
            return "Bereit für deine erste Auswahl"
        }

        return "\(entry.bookCount) " + (entry.bookCount == 1 ? "Buch" : "Bücher")
    }

    private var progressLabel: String {
        guard entry.bookCount > 0 else { return "Noch keine Bücher" }

        if entry.statusCounts.finished == entry.bookCount {
            return "Komplett gelesen"
        }

        return "\(entry.statusCounts.finished) von \(entry.bookCount) gelesen"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CollectionCoverCollageView(books: coverBooks)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                CollectionStatusChips(statusCounts: entry.statusCounts)

                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: entry.statusCounts.progressFraction)
                        .progressViewStyle(.linear)

                    Text(progressLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if entry.hasActiveBooks {
                    Label("Aktiv in Arbeit", systemImage: "book.pages")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CollectionStatusChips: View {
    let statusCounts: CollectionsDashboardStatusCounts

    var body: some View {
        if statusCounts.hasBooks {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    statusChip("\(statusCounts.finished) gelesen")
                    statusChip("\(statusCounts.reading) aktiv")
                    statusChip("\(statusCounts.toRead) geplant")
                }

                VStack(alignment: .leading, spacing: 6) {
                    statusChip("\(statusCounts.finished) gelesen")
                    statusChip("\(statusCounts.reading) aktiv")
                    statusChip("\(statusCounts.toRead) geplant")
                }
            }
        } else {
            statusChip("Noch leer")
        }
    }

    private func statusChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}
