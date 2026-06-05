import SwiftUI

struct CollectionDetailHeaderView: View {
    let state: CollectionDetailState
    let coverBooks: [Book]
    @Binding var nameDraft: String
    let onAddBooks: () -> Void

    private var bookCountText: String {
        state.bookCount == 1 ? "1 Buch" : "\(state.bookCount) Bücher"
    }

    private var progressText: String {
        guard state.bookCount > 0 else { return "Bereit für deine erste Auswahl" }

        if state.statusCounts.finished == state.bookCount {
            return "Alle Bücher gelesen"
        }

        return "\(state.statusCounts.finished) von \(state.bookCount) gelesen"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CollectionCoverCollageView(
                    books: coverBooks,
                    size: CGSize(width: 112, height: 136)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Liste")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("Listenname", text: $nameDraft)
                        .font(.title2.weight(.bold))
                        .textFieldStyle(.plain)
                        .submitLabel(.done)

                    Text(bookCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button(action: onAddBooks) {
                        Label("Bücher hinzufügen", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Spacer(minLength: 0)
            }

            CollectionDetailStatusSummaryView(statusCounts: state.statusCounts)

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: state.statusCounts.progressFraction)
                    .progressViewStyle(.linear)

                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
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

private struct CollectionDetailStatusSummaryView: View {
    let statusCounts: CollectionsDashboardStatusCounts

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                chip("\(statusCounts.finished) gelesen", systemImage: "checkmark.circle")
                chip("\(statusCounts.reading) aktiv", systemImage: "book.pages")
                chip("\(statusCounts.toRead) geplant", systemImage: "bookmark")
            }

            VStack(alignment: .leading, spacing: 8) {
                chip("\(statusCounts.finished) gelesen", systemImage: "checkmark.circle")
                chip("\(statusCounts.reading) aktiv", systemImage: "book.pages")
                chip("\(statusCounts.toRead) geplant", systemImage: "bookmark")
            }
        }
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}
