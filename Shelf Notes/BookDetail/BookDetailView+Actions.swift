import SwiftUI
import SwiftData

#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Actions (mutations / UI actions)
extension BookDetailView {

    // MARK: Notes

    func presentNotesEditor() {
        notesDraft = book.notes
        showingNotesSheet = true
    }

    func saveNotes(_ updatedText: String) {
        guard updatedText != book.notes else { return }
        book.notes = updatedText
        notesDraft = updatedText
        _ = saveDetail()
    }

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
        let out = TagsIndexBuilder.toggledTag(tag, in: book.tags)
        guard out != book.tags else { return }
        book.tags = out
        tagsText = out.joined(separator: ", ")
        _ = saveDetail()
    }

    func addTagsFromDraft() {
        let candidates = TagsIndexBuilder.parsedTags(from: tagDraft)
        guard !candidates.isEmpty else {
            tagDraft = ""
            return
        }

        let out = TagsIndexBuilder.mergedTags(existingTags: book.tags, addedTags: candidates)
        book.tags = out
        tagsText = out.joined(separator: ", ")
        tagDraft = ""
        _ = saveDetail()
    }

    func acceptTagSuggestion(_ suggestion: String) {
        let out = TagsIndexBuilder.mergedTags(existingTags: book.tags, addedTags: [suggestion])
        guard out != book.tags else {
            tagDraft = ""
            return
        }
        book.tags = out
        tagsText = out.joined(separator: ", ")
        tagDraft = ""
        _ = saveDetail()
    }

    func removeTag(_ tag: String) {
        let out = TagsIndexBuilder.removingTag(tag, from: book.tags)
        guard out != book.tags else { return }
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
        guard CollectionMembershipMutation.setMembership(
            isMember,
            book: book,
            collection: collection
        ) else {
            return
        }

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
