import SwiftUI

struct CollectionsHeroCard: View {
    let summary: CollectionsDashboardSummary
    let hasPro: Bool
    let freeCollectionLimit: Int

    private var topCollectionValue: String {
        guard let largestCollection = summary.largestCollection else { return "Noch keine" }
        return largestCollection.name
    }

    private var topCollectionDetail: String {
        guard let largestCollection = summary.largestCollection else { return "Liste erstellen" }
        return "\(largestCollection.bookCount) " + (largestCollection.bookCount == 1 ? "Buch" : "Bücher")
    }

    private var proValue: String {
        if hasPro {
            return "Pro"
        }

        return "\(summary.totalCollections)/\(freeCollectionLimit)"
    }

    private var proDetail: String {
        hasPro ? "unbegrenzt" : "freie Listen"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "rectangle.stack.badge.person.crop")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Deine Leselisten")
                        .font(.title2.weight(.bold))

                    Text("Kuratierte Regale für Reihen, Themen, Urlaube und alles, was du nicht einfach in der Bibliothek verlieren willst.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 142), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                CollectionsHeroMetric(
                    title: "Listen",
                    value: "\(summary.totalCollections)",
                    detail: "gesamt",
                    systemImage: "rectangle.stack"
                )

                CollectionsHeroMetric(
                    title: "Organisiert",
                    value: "\(summary.booksInCollectionsCount)",
                    detail: "Bücher",
                    systemImage: "books.vertical"
                )

                CollectionsHeroMetric(
                    title: "Ohne Liste",
                    value: "\(summary.unassignedBooksCount)",
                    detail: "Bücher",
                    systemImage: "tray"
                )

                CollectionsHeroMetric(
                    title: "Aktiv",
                    value: "\(summary.activeCollectionsCount)",
                    detail: "mit laufenden Büchern",
                    systemImage: "bolt"
                )

                CollectionsHeroMetric(
                    title: "Top Liste",
                    value: topCollectionValue,
                    detail: topCollectionDetail,
                    systemImage: "star"
                )

                CollectionsHeroMetric(
                    title: "Nutzung",
                    value: proValue,
                    detail: proDetail,
                    systemImage: hasPro ? "crown" : "lock.open"
                )
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CollectionsHeroMetric: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
