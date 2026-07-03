//
//  LibraryBookRouletteCard.swift
//  Shelf Notes
//
//  Inline Smart Shelf card for drawing a book from the to-read stack.
//

import SwiftUI

struct LibraryBookRouletteCard: View {
    let roulette: LibraryView.LibraryBookRoulette
    let booksByID: [UUID: Book]
    let appearance: LibraryRowAppearanceSnapshot

    @State private var selectedCandidateID: UUID?

    private var selectedCandidate: LibraryView.LibraryBookRoulette.Candidate? {
        roulette.candidate(for: selectedCandidateID)
    }

    private var selectedBook: Book? {
        guard let selectedCandidate else { return nil }
        return booksByID[selectedCandidate.id]
    }

    private var coverSize: CGSize {
        switch appearance.coverSize {
        case .small:
            return CGSize(width: 48, height: 72)
        case .standard:
            return CGSize(width: 56, height: 84)
        case .large:
            return CGSize(width: 64, height: 96)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Buchroulette", systemImage: "die.face.5")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)

                Text("\(roulette.candidates.count) im Stapel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text("Keine Ahnung, was als Nächstes dran ist? Zieh dir eins vom Stapel.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let selectedCandidate, let selectedBook {
                selectedCandidateContent(candidate: selectedCandidate, book: selectedBook)
            } else {
                Button {
                    drawNextCandidate()
                } label: {
                    Label("Zieh mir eins vom Stapel", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.secondary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func selectedCandidateContent(
        candidate: LibraryView.LibraryBookRoulette.Candidate,
        book: Book
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if appearance.showCovers {
                    LibraryRowCoverView(
                        book: book,
                        size: coverSize,
                        cornerRadius: min(appearance.resolvedCoverCornerRadius, 10),
                        contentMode: appearance.resolvedCoverContentMode,
                        prefersHighResCover: true
                    )
                    .shadow(
                        color: appearance.coverShadowEnabled ? .black.opacity(0.12) : .clear,
                        radius: appearance.coverShadowEnabled ? 4 : 0,
                        x: 0,
                        y: appearance.coverShadowEnabled ? 2 : 0
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(candidate.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if candidate.author.isEmpty == false {
                        Text(candidate.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if candidate.tags.isEmpty == false {
                        tagLine(candidate.tags)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    Label("Öffnen", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    drawNextCandidate()
                } label: {
                    Label("Nochmal ziehen", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gezogenes Buch: \(candidate.title)")
    }

    private func tagLine(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags.prefix(4), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    private func drawNextCandidate() {
        let candidate = roulette.drawCandidate(excluding: selectedCandidateID) { upperBound in
            Int.random(in: 0..<upperBound)
        }
        selectedCandidateID = candidate?.id
    }
}
