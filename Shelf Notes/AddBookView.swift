//
//  AddBookView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Add Book
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var status: ReadingStatus = .toRead
    
    @State private var showingScannerSheet = false
    @State private var pendingScanISBN: String? = nil

    @State private var readFrom: Date = Date()
    @State private var readTo: Date = Date()

    // Existing imported metadata
    @State private var isbn13: String?
    @State private var thumbnailURL: String?
    @State private var publisher: String?
    @State private var publishedDate: String?
    @State private var pageCount: Int?
    @State private var language: String?
    @State private var categories: [String] = []
    @State private var bookDescription: String = ""
    @State private var googleVolumeID: String?

    // ✅ New imported metadata (persisted into Book)
    @State private var subtitle: String?
    @State private var previewLink: String?
    @State private var infoLink: String?
    @State private var canonicalVolumeLink: String?

    @State private var averageRating: Double?
    @State private var ratingsCount: Int?
    @State private var mainCategory: String?

    @State private var coverURLCandidates: [String] = []

    @State private var viewability: String?
    @State private var isPublicDomain: Bool = false
    @State private var isEmbeddable: Bool = false

    @State private var isEpubAvailable: Bool = false
    @State private var isPdfAvailable: Bool = false
    @State private var epubAcsTokenLink: String?
    @State private var pdfAcsTokenLink: String?

    @State private var saleability: String?
    @State private var isEbook: Bool = false

    @State private var showingImportSheet = false

    // track if we currently have quick-added books in this session (and not undone)
    @State private var quickAddActive = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        pendingScanISBN = nil
                        quickAddActive = false
                        showingImportSheet = true
                    } label: {
                        Label("Aus Google Books suchen", systemImage: "magnifyingglass")
                    }

                    Button {
                        pendingScanISBN = nil
                        showingScannerSheet = true
                    } label: {
                        Label("ISBN scannen", systemImage: "barcode.viewfinder")
                    }
                }


                Section("Neues Buch") {
                    TextField("Titel", text: $title)
                    TextField("Autor", text: $author)

                    Picker("Status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                if status == .finished {
                    Section("Gelesen") {
                        DatePicker("Von", selection: $readFrom, displayedComponents: [.date])
                            .onChange(of: readFrom) { _, newValue in
                                if readTo < newValue { readTo = newValue }
                            }

                        DatePicker("Bis", selection: $readTo, in: readFrom...Date(), displayedComponents: [.date])
                            .onChange(of: readTo) { _, newValue in
                                if newValue < readFrom { readFrom = newValue }
                            }
                    }
                }

                if let thumbnailURL, let url = URL(string: thumbnailURL) {
                    Section("Cover") {
                        HStack(alignment: .top, spacing: 12) {

                            // Cover "Card" – echtes Cover-Format, ohne Abschneiden
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.35)

                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()          // <- KEIN Crop
                                } placeholder: {
                                    ProgressView()
                                }
                                .padding(6)                    // <- etwas Luft, falls das Thumbnail nicht 2:3 ist
                            }
                            .frame(width: 120, height: 180)     // 2:3 (120x180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Rechte Seite: Mini-Preview Infos
                            VStack(alignment: .leading, spacing: 6) {
                                Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : title)
                                    .font(.headline)
                                    .lineLimit(3)

                                if !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(author)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                if let isbn13, !isbn13.isEmpty {
                                    Text("ISBN \(isbn13)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                    }
                }



                if hasAnyImportedMetadata {
                    Section("Übernommene Metadaten") {
                        if let isbn13 { LabeledContent("ISBN 13", value: isbn13) }
                        if let publisher { LabeledContent("Verlag", value: publisher) }
                        if let publishedDate { LabeledContent("Erschienen", value: publishedDate) }
                        if let pageCount { LabeledContent("Seiten", value: "\(pageCount)") }
                        if let language { LabeledContent("Sprache", value: language) }
                        if !categories.isEmpty {
                            Text("Kategorien: \(categories.joined(separator: ", "))")
                                .foregroundStyle(.secondary)
                        }
                        if !bookDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(bookDescription)
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                        }
                    }
                }
            }
            .navigationTitle("Buch hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        addBook()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingImportSheet, onDismiss: {
                pendingScanISBN = nil
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if quickAddActive && trimmedTitle.isEmpty {
                    dismiss()
                }
            }) {
                BookImportView(
                    onPick: { imported in
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
                        
                        // ✅ New rich metadata
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
                    }, initialQuery: pendingScanISBN,
                    autoSearchOnAppear: true,
                    onQuickAddHappened: {
                        quickAddActive = true
                    },
                    onQuickAddActiveChanged: { isActive in
                        quickAddActive = isActive
                    }
                )
            }
            .sheet(isPresented: $showingScannerSheet) {
                BarcodeScannerSheet { isbn in
                    pendingScanISBN = isbn
                }
            }
            .onChange(of: showingScannerSheet) { _, isShowing in
                // Scanner ist zu -> wenn wir eine ISBN haben -> Import-Sheet öffnen
                if !isShowing, let isbn = pendingScanISBN, !isbn.isEmpty {
                    quickAddActive = false
                    showingImportSheet = true
                }
            }
        }
    }

    private var hasAnyImportedMetadata: Bool {
        isbn13 != nil
        || thumbnailURL != nil
        || publisher != nil
        || publishedDate != nil
        || pageCount != nil
        || language != nil
        || !categories.isEmpty
        || !bookDescription.isEmpty

        // new fields (optional)
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

    private func addBook() {
        let newBook = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
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

        // ✅ New rich metadata mappings
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
        try? modelContext.save()

        // Generate and sync thumbnail cover if we have any cover candidates.
        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: newBook, modelContext: modelContext)
        }
    }
}

