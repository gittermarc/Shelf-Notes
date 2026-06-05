import SwiftUI

struct CollectionCoverCollageView: View {
    let books: [Book]
    var size: CGSize = CGSize(width: 92, height: 112)

    private var visibleBooks: [Book] {
        Array(books.prefix(4))
    }

    var body: some View {
        ZStack {
            if visibleBooks.isEmpty {
                emptyPlaceholder
            } else {
                collage
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var coverSize: CGSize {
        if visibleBooks.count == 1 {
            return CGSize(width: size.width * 0.68, height: size.height * 0.86)
        }

        return CGSize(width: size.width * 0.44, height: size.height * 0.56)
    }

    private var collage: some View {
        ZStack {
            ForEach(Array(visibleBooks.enumerated()), id: \.element.id) { index, book in
                LibraryRowCoverView(
                    book: book,
                    size: coverSize,
                    cornerRadius: 7,
                    contentMode: .fill
                )
                .shadow(radius: 2, x: 0, y: 1)
                .offset(offset(for: index, count: visibleBooks.count))
                .zIndex(Double(index))
            }
        }
    }

    private var emptyPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.title2)
                    Text("Leer")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private func offset(for index: Int, count: Int) -> CGSize {
        switch count {
        case 1:
            return .zero
        case 2:
            return CGSize(width: index == 0 ? -12 : 12, height: index == 0 ? 6 : -6)
        case 3:
            switch index {
            case 0:
                return CGSize(width: -18, height: 10)
            case 1:
                return CGSize(width: 0, height: -10)
            default:
                return CGSize(width: 18, height: 8)
            }
        default:
            switch index {
            case 0:
                return CGSize(width: -20, height: 12)
            case 1:
                return CGSize(width: -6, height: -12)
            case 2:
                return CGSize(width: 12, height: 8)
            default:
                return CGSize(width: 24, height: -6)
            }
        }
    }
}
