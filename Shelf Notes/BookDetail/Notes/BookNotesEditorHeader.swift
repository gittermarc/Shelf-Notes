import SwiftUI

struct BookNotesEditorHeader: View {
    let book: Book
    let metrics: BookNotesMetrics

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            LibraryRowCoverView(
                book: book,
                size: CGSize(width: 64, height: 96),
                cornerRadius: 14,
                contentMode: .fit,
                prefersHighResCover: true
            )
            .shadow(radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                let author = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
                if !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(metrics.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
