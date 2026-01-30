//
//  InspirationSeedPickerView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 30.01.26.
//

import SwiftUI

/// Small "seed picker" for discovery.
/// Selecting a seed returns a query string that can be fed into `BookImportView(initialQuery:)`.
struct InspirationSeedPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SeedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.title3.weight(.semibold))
                                Text("Stöbern statt Suchen")
                                    .font(.headline)
                                Spacer(minLength: 0)
                            }

                            Text("Tippe auf ein Thema – wir starten direkt eine Google-Books-Suche. Danach kannst du wie gewohnt filtern und sortieren.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SeedSection(title: "Genres", seeds: genreSeeds, columns: columns, onPick: pick)

                    SeedSection(title: "Wissen & Sachbuch", seeds: nonFictionSeeds, columns: columns, onPick: pick)

                    SeedCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Überrasch mich")
                                .font(.headline)

                            Button {
                                pickRandom()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "dice")
                                        .font(.title3.weight(.semibold))
                                        .frame(width: 26)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Zufälliges Thema")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Wenn du einfach nur einen Impuls willst")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Inspiration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Seeds

    private var genreSeeds: [InspirationSeed] {
        [
            .init(title: "Thriller", subtitle: "Spannung pur", systemImage: "bolt.fill", query: "subject:thriller"),
            .init(title: "Krimi", subtitle: "Ermitteln & rätseln", systemImage: "magnifyingglass", query: "subject:crime"),
            .init(title: "Fantasy", subtitle: "Magie & Welten", systemImage: "wand.and.stars", query: "subject:fantasy"),
            .init(title: "Sci-Fi", subtitle: "Zukunft & Tech", systemImage: "sparkles.square.filled.on.square", query: "subject:\"science fiction\""),
            .init(title: "Horror", subtitle: "Dunkel & creepy", systemImage: "theatermasks", query: "subject:horror"),
            .init(title: "Romance", subtitle: "Herzklopfen", systemImage: "heart.fill", query: "subject:romance"),
            .init(title: "Humor", subtitle: "Leicht & witzig", systemImage: "face.smiling", query: "humor romane"),
            .init(title: "Klassiker", subtitle: "Must-reads", systemImage: "book.closed", query: "klassiker roman"),
        ]
    }

    private var nonFictionSeeds: [InspirationSeed] {
        [
            .init(title: "Biografien", subtitle: "Menschen & Leben", systemImage: "person.text.rectangle", query: "subject:biography"),
            .init(title: "True Crime", subtitle: "Echte Fälle", systemImage: "handcuffs", query: "\"true crime\""),
            .init(title: "Psychologie", subtitle: "Kopf & Verhalten", systemImage: "brain", query: "subject:psychology"),
            .init(title: "Business", subtitle: "Strategie & Growth", systemImage: "briefcase.fill", query: "subject:business"),
            .init(title: "Produktivität", subtitle: "Gewohnheiten & Fokus", systemImage: "checklist", query: "produktivität gewohnheiten"),
            .init(title: "Geschichte", subtitle: "Epochen & Stories", systemImage: "clock", query: "subject:history"),
            .init(title: "Wissenschaft", subtitle: "Pop-Science", systemImage: "atom", query: "popular science"),
            .init(title: "Reise", subtitle: "Fernweh", systemImage: "airplane", query: "reisebericht"),
        ]
    }

    private var allSeeds: [InspirationSeed] {
        genreSeeds + nonFictionSeeds
    }

    // MARK: - Actions

    private func pick(_ seed: InspirationSeed) {
        onSelect(seed.query)
        dismiss()
    }

    private func pickRandom() {
        guard let seed = allSeeds.randomElement() else { return }
        pick(seed)
    }
}

// MARK: - UI Components

private struct InspirationSeed: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let query: String
}

private struct SeedSection: View {
    let title: String
    let seeds: [InspirationSeed]
    let columns: [GridItem]
    let onPick: (InspirationSeed) -> Void

    var body: some View {
        SeedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(seeds) { seed in
                        SeedTile(seed: seed) {
                            onPick(seed)
                        }
                    }
                }
            }
        }
    }
}

private struct SeedTile: View {
    let seed: InspirationSeed
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: seed.systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(seed.title)
                        .font(.subheadline.weight(.semibold))
                    Text(seed.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SeedCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
