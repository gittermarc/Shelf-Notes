import SwiftUI
import SwiftData

#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Actions (mutations / UI actions)
extension BookDetailView {

    // MARK: Ratings

    func resetUserRating() {
        book.userRatingPlot = 0
        book.userRatingCharacters = 0
        book.userRatingWritingStyle = 0
        book.userRatingAtmosphere = 0
        book.userRatingGenreFit = 0
        book.userRatingPresentation = 0
        _ = saveDetail()
    }

    // MARK: - Cover upload helpers

    #if canImport(PhotosUI)
    func handlePickedCoverItem(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isUploadingCover = true
        coverUploadError = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(
                        domain: "CoverUpload",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Konnte Bilddaten nicht laden."]
                    )
                }

                // Saves full-res locally + sets synced thumbnail (`book.userCoverData`).
                try await CoverThumbnailer.applyUserPickedCover(imageData: data, to: book, modelContext: modelContext)
            } catch {
                await MainActor.run {
                    coverUploadError = error.localizedDescription
                }
            }

            await MainActor.run {
                isUploadingCover = false
                pickedCoverItem = nil
            }
        }
    }
    #endif

    func removeUserCover() {
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }
        book.userCoverFileName = nil
        book.userCoverData = nil
        _ = saveDetail()

        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
        }
    }

    // MARK: - Delete

    func deleteBook() {
        // Clean up local user cover file if any
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }

        modelContext.delete(book)
        _ = saveDetail()
        dismiss()
    }

    // MARK: - Tags

    func toggleTag(_ tag: String) {
        let n = normalizeTagString(tag)
        guard !n.isEmpty else { return }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }

        if let idx = current.firstIndex(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
            current.remove(at: idx)
        } else {
            current.append(n)
        }

        // dedupe case-insensitive, preserve order
        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        _ = saveDetail()
    }

    func addTagsFromDraft() {
        let parts = tagDraft
            .split(separator: ",")
            .map { normalizeTagString(String($0)) }
            .filter { !$0.isEmpty }

        let single = normalizeTagString(tagDraft)
        let candidates = parts.isEmpty ? ([single].filter { !$0.isEmpty }) : parts

        guard !candidates.isEmpty else {
            tagDraft = ""
            return
        }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }

        for p in candidates {
            if !current.contains(where: { $0.caseInsensitiveCompare(p) == .orderedSame }) {
                current.append(p)
            }
        }

        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        tagDraft = ""
        _ = saveDetail()
    }

    func acceptTagSuggestion(_ suggestion: String) {
        let n = normalizeTagString(suggestion)
        guard !n.isEmpty else { return }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }
        if !current.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
            current.append(n)
        }

        // dedupe case-insensitive, preserve order
        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        tagDraft = ""
        _ = saveDetail()
    }

    func removeTag(_ tag: String) {
        let n = normalizeTagString(tag)
        guard !n.isEmpty else { return }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }
        current.removeAll { $0.caseInsensitiveCompare(n) == .orderedSame }

        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        _ = saveDetail()
    }

    // MARK: - Collections helpers

    func requestNewCollection() {
        let count = allCollections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNewCollectionSheet = true
        } else {
            showingPaywall = true
        }
    }

    func setMembership(_ isMember: Bool, for collection: BookCollection) {
        var cols = book.collectionsSafe
        var books = collection.booksSafe

        if isMember {
            if !cols.contains(where: { $0.id == collection.id }) { cols.append(collection) }
            if !books.contains(where: { $0.id == book.id }) { books.append(book) }
        } else {
            cols.removeAll { $0.id == collection.id }
            books.removeAll { $0.id == book.id }
        }

        book.collectionsSafe = cols
        collection.booksSafe = books
        collection.updatedAt = Date()

        _ = saveDetail()
    }

    func createAndAttachCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing = allCollections.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            setMembership(true, for: existing)
            return
        }

        let newCol = BookCollection(name: trimmed)
        modelContext.insert(newCol)
        setMembership(true, for: newCol)
    }
}
