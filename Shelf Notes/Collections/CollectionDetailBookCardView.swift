import SwiftUI

struct CollectionDetailBookCardView: View {
    let book: Book
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            NavigationLink {
                BookDetailView(book: book)
            } label: {
                LibraryRowAppearanceReader { rowAppearance in
                    BookRowView(book: book, appearance: rowAppearance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aus Liste entfernen")
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Aus Liste entfernen", systemImage: "trash")
            }
        }
    }
}
