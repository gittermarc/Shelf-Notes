//
//  BookDetailRatingViews.swift
//  Shelf Notes
//
//  Extracted from BookDetailView.swift to keep it slimmer.
//  (No functional changes)
//

import SwiftUI
import SwiftData

struct RatingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book
    let onReset: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if book.status != .finished {
                    Section {
                        Text("Bewertungen sind erst möglich, wenn der Status auf „Gelesen“ steht.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        if hasAnyUserRatingValue {
                            Button(role: .destructive) {
                                onReset()
                            } label: {
                                Label("Bewertung zurücksetzen", systemImage: "trash")
                            }
                        }
                    }

                    Section("Kriterien") {
                        UserRatingRow(
                            title: "Handlung",
                            subtitle: "Originell, logisch, Tempo, Wendungen",
                            rating: $book.userRatingPlot
                        ) { onSave() }

                        UserRatingRow(
                            title: "Charaktere",
                            subtitle: "Glaubwürdig & identifizierbar",
                            rating: $book.userRatingCharacters
                        ) { onSave() }

                        UserRatingRow(
                            title: "Schreibstil",
                            subtitle: "Sprache, Rhythmus, Flow",
                            rating: $book.userRatingWritingStyle
                        ) { onSave() }

                        UserRatingRow(
                            title: "Atmosphäre",
                            subtitle: "Welt & emotionale Wirkung",
                            rating: $book.userRatingAtmosphere
                        ) { onSave() }

                        UserRatingRow(
                            title: "Genre-Fit",
                            subtitle: "Erwartungen ans Genre erfüllt?",
                            rating: $book.userRatingGenreFit
                        ) { onSave() }

                        UserRatingRow(
                            title: "Aufmachung",
                            subtitle: "Cover/Design/Optik",
                            rating: $book.userRatingPresentation
                        ) { onSave() }
                    }

                    Section("Gesamt") {
                        if let avg = book.userRatingAverage1 {
                            HStack(spacing: 10) {
                                StarsView(rating: avg)
                                Text(String(format: "%.1f", avg) + " / 5")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Spacer()
                            }
                        } else {
                            Text("Noch nicht bewertet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Bewerten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var hasAnyUserRatingValue: Bool {
        book.userRatingValues.contains(where: { $0 > 0 })
    }
}

struct StarRatingPicker: View {
    @Binding var rating: Int
    var onChange: (() -> Void)? = nil

    private let maxStars: Int = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...maxStars, id: \.self) { i in
                Button {
                    if rating == i { rating = 0 } else { rating = i }
                    onChange?()
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(i <= rating ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bewertung \(i) von \(maxStars)")
            }
        }
    }
}

struct UserRatingRow: View {
    let title: String
    let subtitle: String
    @Binding var rating: Int
    let onChange: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            StarRatingPicker(rating: $rating, onChange: onChange)
                .accessibilityLabel(title)
        }
        .contentShape(Rectangle())
    }
}
