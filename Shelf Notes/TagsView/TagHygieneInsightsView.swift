import SwiftUI

struct TagHygieneInsightsSection: View {
    let report: TagHygieneReport
    let books: [Book]

    var body: some View {
        if report.hasInsights {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aufräumen empfohlen")
                        .font(.headline)

                    Text("Nur Hinweise. Es wird nichts automatisch geändert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(Array(report.insights.prefix(4))) { insight in
                        NavigationLink {
                            destination(for: insight)
                        } label: {
                            TagHygieneInsightCard(insight: insight)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for insight: TagHygieneInsight) -> some View {
        switch insight.kind {
        case .untaggedBooks:
            UntaggedBooksView(books: books)
        case .formattingConflict, .duplicateCandidate, .singleUseTags:
            if let primaryTag = insight.primaryTag, !primaryTag.isEmpty {
                TagDetailView(tag: primaryTag, books: books)
            } else {
                UntaggedBooksView(books: books)
            }
        }
    }
}

private struct TagHygieneInsightCard: View {
    let insight: TagHygieneInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if !insight.affectedTags.isEmpty {
                    TagHygieneTagPreview(tags: insight.affectedTags)
                }

                HStack(spacing: 8) {
                    Label(affectedBooksLabel, systemImage: "books.vertical")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Text(insight.actionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
        .accessibilityLabel("\(insight.title), \(affectedBooksLabel)")
    }

    private var affectedBooksLabel: String {
        let count = insight.affectedBooksCount
        return count == 1 ? "1 Buch betroffen" : "\(count) Bücher betroffen"
    }
}

private struct TagHygieneTagPreview: View {
    let tags: [String]

    var body: some View {
        let visibleTags = Array(tags.prefix(4))
        let remainingCount = max(0, tags.count - visibleTags.count)

        HStack(spacing: 6) {
            ForEach(visibleTags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}
