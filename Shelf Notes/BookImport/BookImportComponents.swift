//
/*  BookImportComponents.swift
    Shelf Notes

    Reusable UI components used by BookImportView.
*/

import SwiftUI

struct BookImportResultCard: View {
    let volume: GoogleBookVolume
    let isAlreadyInLibrary: Bool
    let onDetails: () -> Void
    let onQuickAdd: (ReadingStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onDetails) {
                HStack(alignment: .top, spacing: 12) {
                    cover

                    VStack(alignment: .leading, spacing: 6) {
                        Text(volume.bestTitle)
                            .font(.headline)
                            .lineLimit(2)

                        if !volume.bestAuthors.isEmpty {
                            Text(volume.bestAuthors)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            if let isbn = volume.isbn13 {
                                metaPill(text: "ISBN \(isbn)", systemImage: "barcode")
                            }

                            if let year = volume.volumeInfo.publishedDate, !year.isEmpty {
                                metaPill(text: year, systemImage: "calendar")
                            }
                        }
                        .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if isAlreadyInLibrary {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Bereits in deiner Bibliothek")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            } else {
                HStack(spacing: 8) {
                    BookImportQuickAddButton(title: "Will lesen", systemImage: "bookmark") { onQuickAdd(.toRead) }
                    BookImportQuickAddButton(title: "Lese gerade", systemImage: "book") { onQuickAdd(.reading) }
                    BookImportQuickAddButton(title: "Gelesen", systemImage: "checkmark.circle") { onQuickAdd(.finished) }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var cover: some View {
        let best = volume.bestCoverURLString ?? volume.bestThumbnailURLString

        if let urlString = best,
           let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.12)
                    .overlay(ProgressView())
            }
            .frame(width: 54, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 54, height: 78)
                .opacity(0.12)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }

    private func metaPill(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
    }
}

struct BookImportQuickAddButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) hinzufügen")
    }
}

struct BookImportUndoToastView: View {
    let title: String
    let status: ReadingStatus
    let thumbnailURL: String?
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var statusLabel: String {
        switch status {
        case .toRead: return "Will lesen"
        case .reading: return "Lese gerade"
        case .finished: return "Gelesen"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            cover

            VStack(alignment: .leading, spacing: 2) {
                Text("Hinzugefügt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("Rückgängig") {
                onUndo()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hinweis schließen")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8, y: 3)
    }

    @ViewBuilder
    private var cover: some View {
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.12)
                    .overlay(ProgressView())
            }
            .frame(width: 40, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 40, height: 56)
                .opacity(0.12)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }
}
