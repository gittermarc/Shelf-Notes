import SwiftUI

struct TagCardView: View {
    let entry: TagsDashboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "tag.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(entry.tag)")
                        .font(.headline)
                        .lineLimit(1)

                    Text(entry.statusCounts.compactLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.bookCount)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()

                    Text(entry.bookCount == 1 ? "Buch" : "Bücher")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                TagCardMiniMetric(
                    title: "Gelesen",
                    value: entry.statusCounts.finished,
                    systemImage: "checkmark.circle"
                )

                TagCardMiniMetric(
                    title: "Aktiv",
                    value: entry.statusCounts.reading,
                    systemImage: "book"
                )

                TagCardMiniMetric(
                    title: "Geplant",
                    value: entry.statusCounts.toRead,
                    systemImage: "bookmark"
                )
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tag \(entry.tag), \(entry.bookCount) Bücher")
    }
}

private struct TagCardMiniMetric: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
