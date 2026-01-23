import SwiftUI

// MARK: - Toolbar
extension BookDetailView {

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if showCompactNavTitle {
                VStack(spacing: 0) {
                    Text(compactNavTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if !compactNavSubtitle.isEmpty {
                        Text(compactNavSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            // Share
            if let shareURL = shareURLCandidate {
                if #available(iOS 16.0, *) {
                    ShareLink(item: shareURL, subject: Text(shareSubject), message: Text(shareMessage)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        presentShare(items: [shareURL])
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            } else {
                if #available(iOS 16.0, *) {
                    ShareLink(item: shareMessage, subject: Text(shareSubject)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        presentShare(items: [shareMessage])
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }

            // Apple-style actions menu (Cover ändern / Löschen)
            Menu {
                Section {
                    coverChangeMenuItems
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Aktionen")
        }
    }

    @ViewBuilder
    var coverChangeMenuItems: some View {
        #if canImport(PhotosUI)
        Button {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showingPhotoPicker = true }
        } label: {
            Label(isUploadingCover ? "Lade …" : "Cover aus Fotos wählen", systemImage: "photo")
        }
        .disabled(isUploadingCover)
        #else
        Label("Cover-Upload nicht verfügbar", systemImage: "exclamationmark.triangle")
        #endif

        if book.userCoverFileName != nil {
            Button(role: .destructive) {
                removeUserCover()
            } label: {
                Label("Benutzer-Cover entfernen", systemImage: "trash")
            }
        }

        if !book.coverURLCandidates.isEmpty {
            Button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showingOnlineCoverPicker = true }
            } label: {
                Label("Online-Cover auswählen", systemImage: "photo.on.rectangle")
            }
        }
    }

    var compactNavTitle: String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Ohne Titel" : t
    }

    var compactNavSubtitle: String {
        book.author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shareSubject: String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Buch" : t
    }

    var shareMessage: String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if !t.isEmpty { parts.append("„\(t)“") }
        if !a.isEmpty { parts.append("von \(a)") }

        let base = parts.isEmpty ? "Buch" : parts.joined(separator: " ")
        if let url = shareURLCandidate?.absoluteString {
            return base + "\n" + url
        }
        return base
    }

    var shareURLCandidate: URL? {
        // Prefer canonical/info/preview links if available
        if let u = urlFromString(book.canonicalVolumeLink) { return u }
        if let u = urlFromString(book.infoLink) { return u }
        if let u = urlFromString(book.previewLink) { return u }
        return nil
    }

    func presentShare(items: [Any]) {
        #if canImport(UIKit)
        shareItems = items
        showingShareSheet = true
        #endif
    }
}
