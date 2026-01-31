//
//  AddBookViewModel.swift
//  Shelf Notes
//
//  Created by Marc Fechner + ChatGPT on 31.01.26.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class AddBookViewModel: ObservableObject {

    // MARK: - Routing

    @Published var activeSheet: AddBookSheet? = nil

    private var lastPresentedSheet: AddBookSheet? = nil
    private var queuedImportQueryAfterDismiss: String? = nil

    func openImport(query: String? = nil) {
        queuedImportQueryAfterDismiss = nil
        quickAddActive = false
        present(.importBooks(initialQuery: query))
    }

    func openScanner() {
        queuedImportQueryAfterDismiss = nil
        present(.scanner)
    }

    func openInspiration() {
        queuedImportQueryAfterDismiss = nil
        present(.inspiration)
    }

    func queueImportAfterDismiss(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queuedImportQueryAfterDismiss = trimmed
    }

    struct SheetDismissOutcome {
        let dismissedSheet: AddBookSheet?
        let shouldDismissAddBookView: Bool
    }

    /// Call this from `AddBookView.sheet(onDismiss:)`.
    func handleSheetDismiss() -> SheetDismissOutcome {
        let dismissed = lastPresentedSheet

        // 1) Dismiss AddBookView when user quick-added books and never selected a book to edit.
        let shouldDismiss = (dismissed?.isImport == true) && quickAddActive && trimmedTitle.isEmpty

        // 2) If a scanner/inspiration flow queued an import query, open the import sheet now.
        if let q = queuedImportQueryAfterDismiss {
            queuedImportQueryAfterDismiss = nil
            openImport(query: q)
        }

        return SheetDismissOutcome(dismissedSheet: dismissed, shouldDismissAddBookView: shouldDismiss)
    }

    private func present(_ sheet: AddBookSheet) {
        lastPresentedSheet = sheet
        activeSheet = sheet
    }

    // MARK: - User-editable fields

    @Published var title: String = ""
    @Published var author: String = ""
    @Published var status: ReadingStatus = .toRead

    @Published var readFrom: Date = Date()
    @Published var readTo: Date = Date()

    // MARK: - Imported metadata

    @Published var isbn13: String? = nil
    @Published var thumbnailURL: String? = nil
    @Published var publisher: String? = nil
    @Published var publishedDate: String? = nil
    @Published var pageCount: Int? = nil
    @Published var language: String? = nil
    @Published var categories: [String] = []
    @Published var bookDescription: String = ""
    @Published var googleVolumeID: String? = nil

    // Rich metadata
    @Published var subtitle: String? = nil
    @Published var previewLink: String? = nil
    @Published var infoLink: String? = nil
    @Published var canonicalVolumeLink: String? = nil

    @Published var averageRating: Double? = nil
    @Published var ratingsCount: Int? = nil
    @Published var mainCategory: String? = nil

    @Published var coverURLCandidates: [String] = []

    @Published var viewability: String? = nil
    @Published var isPublicDomain: Bool = false
    @Published var isEmbeddable: Bool = false

    @Published var isEpubAvailable: Bool = false
    @Published var isPdfAvailable: Bool = false
    @Published var epubAcsTokenLink: String? = nil
    @Published var pdfAcsTokenLink: String? = nil

    @Published var saleability: String? = nil
    @Published var isEbook: Bool = false

    // MARK: - UI state

    @Published var isDescriptionExpanded: Bool = false

    /// Track if we currently have quick-added books in this session (and not undone)
    @Published var quickAddActive: Bool = false

    // MARK: - Derived values

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAuthor: String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSubtitle: String {
        (subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDescription: String {
        bookDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var publishedYear: String? {
        publishedYear(from: publishedDate)
    }

    var coverCandidatesAll: [String] {
        var out: [String] = []

        func add(_ s: String?) {
            guard let s else { return }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        add(thumbnailURL)
        for c in coverURLCandidates {
            add(c)
        }
        return out
    }

    var bestCoverURL: URL? {
        // Best effort background: prefer thumbnail, otherwise first candidate.
        if let u = url(from: thumbnailURL) { return u }
        return url(from: coverURLCandidates.first)
    }

    var previewURL: URL? { url(from: previewLink) }
    var infoURL: URL? { url(from: infoLink) }
    var canonicalURL: URL? { url(from: canonicalVolumeLink) }

    var hasAnyLinks: Bool {
        previewURL != nil || infoURL != nil || canonicalURL != nil
    }

    var hasAnyImportedMetadata: Bool {
        isbn13 != nil
        || thumbnailURL != nil
        || publisher != nil
        || publishedDate != nil
        || pageCount != nil
        || language != nil
        || !categories.isEmpty
        || !bookDescription.isEmpty

        // rich fields
        || subtitle != nil
        || previewLink != nil
        || infoLink != nil
        || canonicalVolumeLink != nil
        || averageRating != nil
        || ratingsCount != nil
        || mainCategory != nil
        || !coverURLCandidates.isEmpty
        || viewability != nil
        || isPublicDomain
        || isEmbeddable
        || isEpubAvailable
        || isPdfAvailable
        || epubAcsTokenLink != nil
        || pdfAcsTokenLink != nil
        || saleability != nil
        || isEbook
    }

    var hasAvailabilityChips: Bool {
        isEbook || isEpubAvailable || isPdfAvailable || isEmbeddable || isPublicDomain || saleability != nil || viewability != nil
    }

    // MARK: - Actions

    func applyImportedBook(_ imported: ImportedBook) {
        title = imported.title
        author = imported.author

        isbn13 = imported.isbn13
        thumbnailURL = imported.thumbnailURL
        publisher = imported.publisher
        publishedDate = imported.publishedDate
        pageCount = imported.pageCount
        language = imported.language
        categories = imported.categories
        bookDescription = imported.description
        googleVolumeID = imported.googleVolumeID

        subtitle = imported.subtitle
        previewLink = imported.previewLink
        infoLink = imported.infoLink
        canonicalVolumeLink = imported.canonicalVolumeLink

        averageRating = imported.averageRating
        ratingsCount = imported.ratingsCount
        mainCategory = imported.mainCategory

        coverURLCandidates = imported.coverURLCandidates

        viewability = imported.viewability
        isPublicDomain = imported.isPublicDomain
        isEmbeddable = imported.isEmbeddable

        isEpubAvailable = imported.isEpubAvailable
        isPdfAvailable = imported.isPdfAvailable
        epubAcsTokenLink = imported.epubAcsTokenLink
        pdfAcsTokenLink = imported.pdfAcsTokenLink

        saleability = imported.saleability
        isEbook = imported.isEbook
    }

    func save(modelContext: ModelContext) {
        let newBook = Book(
            title: trimmedTitle,
            author: trimmedAuthor,
            status: status
        )

        if status == .finished {
            newBook.readFrom = readFrom
            newBook.readTo = readTo
        }

        // Existing mappings
        newBook.isbn13 = isbn13
        newBook.thumbnailURL = thumbnailURL
        newBook.publisher = publisher
        newBook.publishedDate = publishedDate
        newBook.pageCount = pageCount
        newBook.language = language
        newBook.categories = categories
        newBook.bookDescription = bookDescription
        newBook.googleVolumeID = googleVolumeID

        // Rich metadata
        newBook.subtitle = subtitle
        newBook.previewLink = previewLink
        newBook.infoLink = infoLink
        newBook.canonicalVolumeLink = canonicalVolumeLink

        newBook.averageRating = averageRating
        newBook.ratingsCount = ratingsCount
        newBook.mainCategory = mainCategory

        newBook.coverURLCandidates = coverURLCandidates

        newBook.viewability = viewability
        newBook.isPublicDomain = isPublicDomain
        newBook.isEmbeddable = isEmbeddable

        newBook.isEpubAvailable = isEpubAvailable
        newBook.isPdfAvailable = isPdfAvailable
        newBook.epubAcsTokenLink = epubAcsTokenLink
        newBook.pdfAcsTokenLink = pdfAcsTokenLink

        newBook.saleability = saleability
        newBook.isEbook = isEbook

        modelContext.insert(newBook)
        modelContext.saveWithDiagnostics()

        // Generate and sync thumbnail cover if we have any cover candidates.
        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: newBook, modelContext: modelContext)
        }
    }

    // MARK: - Helpers

    private func publishedYear(from s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Accept "YYYY" or "YYYY-MM-DD" or similar.
        if s.count >= 4 {
            let y = String(s.prefix(4))
            if Int(y) != nil { return y }
        }
        return nil
    }

    private func url(from s: String?) -> URL? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return URL(string: t)
    }
}
