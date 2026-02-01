//
//  ManualBookAddSheet.swift
//  Shelf Notes
//
//  Created by Marc Fechner + ChatGPT on 01.02.26.
//

import SwiftUI
import SwiftData

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

/// "Notfall"-Flow: Ein Buch komplett ohne Google Books hinzufügen.
///
/// Ziel:
/// - Manuelles Hinzufügen ist dezent (über Import-Kachel erreichbar)
/// - Minimaler, schneller Flow: Titel/Autor/ISBN + optional Cover-Foto
/// - Speichert sofort in SwiftData + erzeugt synced Thumbnail via `CoverThumbnailer`
struct ManualBookAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onBookAdded: () -> Void

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var isbn: String = ""
    @State private var status: ReadingStatus = .toRead

    @State private var readFrom: Date = Date()
    @State private var readTo: Date = Date()

    #if canImport(PhotosUI)
    @State private var pickedCoverItem: PhotosPickerItem?
    #endif

    @State private var pickedCoverData: Data? = nil
    @State private var isLoadingCover: Bool = false

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAuthor: String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedISBN: String {
        isbn.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    AddBookCard(title: "Kurz & schmerzlos") {
                        Text("Wenn Google Books mal streikt, geht’s auch von Hand: Titel/Autor/ISBN eintippen und optional ein Cover aus deinen Fotos wählen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    AddBookCard(title: "Cover") {
                        HStack(alignment: .top, spacing: 14) {
                            coverPreview

                            VStack(alignment: .leading, spacing: 10) {
                                #if canImport(PhotosUI)
                                PhotosPicker(selection: $pickedCoverItem, matching: .images) {
                                    Label(pickedCoverData == nil ? "Cover auswählen" : "Cover ändern", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isSaving)
                                #else
                                Label("Cover auswählen (nicht verfügbar)", systemImage: "photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                #endif

                                if pickedCoverData != nil {
                                    Button(role: .destructive) {
                                        pickedCoverData = nil
                                        #if canImport(PhotosUI)
                                        pickedCoverItem = nil
                                        #endif
                                    } label: {
                                        Label("Cover entfernen", systemImage: "trash")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isSaving)
                                }

                                if isLoadingCover {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("Bild wird geladen …")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Tipp: Das Foto bleibt in hoher Qualität lokal – in iCloud landet nur ein kleines Thumbnail.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    AddBookCard(title: "Details") {
                        VStack(spacing: 12) {
                            AddBookTextFieldRow(title: "Titel", systemImage: "book", text: $title)
                            AddBookTextFieldRow(title: "Autor", systemImage: "person", text: $author)

                            HStack(spacing: 10) {
                                Image(systemName: "barcode")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)

                                TextField("ISBN (optional)", text: $isbn)
                                    .keyboardType(.numbersAndPunctuation)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)

                                if !isbn.isEmpty {
                                    Button {
                                        isbn = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.primary.opacity(0.08), lineWidth: 1)
                            )

                            AddBookSubsection(title: "Status") {
                                Picker("Status", selection: $status) {
                                    ForEach(ReadingStatus.allCases) { s in
                                        Text(s.displayName).tag(s)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            if status == .finished {
                                AddBookSubsection(title: "Gelesen") {
                                    VStack(spacing: 10) {
                                        DatePicker("Von", selection: $readFrom, in: ...Date(), displayedComponents: .date)
                                            .onChange(of: readFrom) { _, newValue in
                                                if readTo < newValue { readTo = newValue }
                                            }

                                        DatePicker("Bis", selection: $readTo, in: readFrom...Date(), displayedComponents: .date)
                                            .onChange(of: readTo) { _, newValue in
                                                if readFrom > newValue { readFrom = newValue }
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Manuell hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Hinzufügen")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || trimmedTitle.isEmpty || isLoadingCover)
                }
            }
        }
        .alert(
            "Konnte Buch nicht speichern",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue { errorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
        #if canImport(PhotosUI)
        .onChange(of: pickedCoverItem) { _, newItem in
            handlePickedCoverItem(newItem)
        }
        #endif
    }

    @ViewBuilder
    private var coverPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)

            #if canImport(UIKit)
            if let data = pickedCoverData,
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                BookCoverPlaceholder(cornerRadius: 14)
                    .padding(10)
                    .foregroundStyle(.secondary)
            }
            #else
            BookCoverPlaceholder(cornerRadius: 14)
                .padding(10)
                .foregroundStyle(.secondary)
            #endif

            if isLoadingCover {
                ProgressView()
            }
        }
        .frame(width: 96, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        )
        .accessibilityLabel("Cover Vorschau")
    }

    #if canImport(PhotosUI)
    private func handlePickedCoverItem(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isLoadingCover = true
        pickedCoverData = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(
                        domain: "ManualBookAdd",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Konnte Bilddaten nicht laden."]
                    )
                }

                await MainActor.run {
                    pickedCoverData = data
                    isLoadingCover = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingCover = false
                }
            }
        }
    }
    #endif

    private func save() {
        let tTitle = trimmedTitle
        guard !tTitle.isEmpty else { return }

        let tAuthor = trimmedAuthor
        let tIsbn = trimmedISBN

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let newBook = Book(title: tTitle, author: tAuthor, status: status)

                if status == .finished {
                    newBook.readFrom = readFrom
                    newBook.readTo = readTo
                }

                if !tIsbn.isEmpty {
                    newBook.isbn13 = tIsbn
                }

                modelContext.insert(newBook)
                modelContext.saveWithDiagnostics()

                if let coverBytes = pickedCoverData {
                    try await CoverThumbnailer.applyUserPickedCover(imageData: coverBytes, to: newBook, modelContext: modelContext)
                } else {
                    // Best-effort: ensure at least a thumbnail exists if any remote URLs exist (usually none in manual flow).
                    await CoverThumbnailer.backfillThumbnailIfNeeded(for: newBook, modelContext: modelContext)
                }

                isSaving = false
                onBookAdded()
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
