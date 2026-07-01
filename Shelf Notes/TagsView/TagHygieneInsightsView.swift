import SwiftUI

struct TagHygieneInsightsSection: View {
    let report: TagHygieneReport
    let domainIndex: TagsDomainIndex
    let books: [Book]
    let onApplyCleanup: (TagLibraryMutationResult) -> Void

    @State private var pendingCleanupPlan: TagHygieneCleanupPlan?
    @State private var cleanupSuccess: TagHygieneCleanupSuccess?

    var body: some View {
        Group {
            if report.hasInsights {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aufräumen empfohlen")
                            .font(.headline)

                        Text("Kontrollierte Hinweise. Änderungen passieren erst nach deiner Bestätigung.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(report.insights.prefix(4))) { insight in
                            let cleanupPlan = TagHygieneCleanupBuilder.plan(
                                for: insight,
                                index: domainIndex
                            )

                            TagHygieneInsightCard(
                                insight: insight,
                                cleanupPlan: cleanupPlan,
                                onCleanup: { plan in
                                    pendingCleanupPlan = plan
                                }
                            ) {
                                destination(for: insight)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $pendingCleanupPlan) { plan in
            TagHygieneCleanupConfirmationSheet(plan: plan) { result in
                onApplyCleanup(result)
                cleanupSuccess = TagHygieneCleanupSuccess(message: successMessage(for: plan))
            }
        }
        .alert(
            "Tags aktualisiert",
            isPresented: isCleanupSuccessPresented,
            presenting: cleanupSuccess
        ) { _ in
            Button("OK", role: .cancel) {
                cleanupSuccess = nil
            }
        } message: { success in
            Text(success.message)
        }
    }

    private var isCleanupSuccessPresented: Binding<Bool> {
        Binding(
            get: { cleanupSuccess != nil },
            set: { isPresented in
                if !isPresented {
                    cleanupSuccess = nil
                }
            }
        )
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

    private func successMessage(for plan: TagHygieneCleanupPlan) -> String {
        let bookLabel = plan.affectedBooksCount == 1 ? "1 Buch" : "\(plan.affectedBooksCount) Bücher"

        switch plan.kind {
        case .normalizeFormatting:
            return "Die Schreibweise wurde für \(bookLabel) vereinheitlicht."
        case .mergeDuplicates:
            return "Die Tags wurden für \(bookLabel) zusammengeführt."
        case .removeSingleUseTag:
            return "Das Einmal-Tag wurde von \(bookLabel) entfernt."
        }
    }
}

private struct TagHygieneCleanupSuccess: Hashable {
    let message: String
}

private struct TagHygieneInsightCard<Destination: View>: View {
    let insight: TagHygieneInsight
    let cleanupPlan: TagHygieneCleanupPlan?
    let onCleanup: (TagHygieneCleanupPlan) -> Void
    let destination: Destination

    init(
        insight: TagHygieneInsight,
        cleanupPlan: TagHygieneCleanupPlan?,
        onCleanup: @escaping (TagHygieneCleanupPlan) -> Void,
        @ViewBuilder destination: () -> Destination
    ) {
        self.insight = insight
        self.cleanupPlan = cleanupPlan
        self.onCleanup = onCleanup
        self.destination = destination()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                    Label(affectedBooksLabel, systemImage: "books.vertical")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                NavigationLink {
                    destination
                } label: {
                    Label(insight.actionTitle, systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)

                if let cleanupPlan {
                    Button(role: cleanupPlan.isDestructive ? .destructive : nil) {
                        onCleanup(cleanupPlan)
                    } label: {
                        Label(cleanupPlan.actionTitle, systemImage: cleanupPlan.kind.systemImage)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .font(.caption.weight(.semibold))
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
