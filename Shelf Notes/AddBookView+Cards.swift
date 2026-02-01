//
//  AddBookView+Cards.swift
//  Shelf Notes
//
//  Created by Marc Fechner + ChatGPT on 31.01.26.
//

import SwiftUI

extension AddBookView {

    // MARK: - Hero

    @ViewBuilder
    var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)

            if let bg = vm.bestCoverURL {
                CachedAsyncImage(url: bg) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .opacity(0.18)
                        .blur(radius: 28)
                        .clipped()
                } placeholder: {
                    Color.clear
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(alignment: .center, spacing: 14) {
                coverView

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.trimmedTitle.isEmpty ? "Neues Buch" : vm.trimmedTitle)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)

                        if !vm.trimmedSubtitle.isEmpty {
                            Text(vm.trimmedSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if !vm.trimmedAuthor.isEmpty {
                            Text(vm.trimmedAuthor)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let r = vm.averageRating {
                        HStack(spacing: 6) {
                            StarsView(rating: r)

                            if let c = vm.ratingsCount {
                                Text("(\(c))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !vm.categories.isEmpty {
                        WrapChipsView(chips: vm.categories, maxVisible: 4)
                    } else if let main = vm.mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !main.isEmpty {
                        HStack {
                            Chip(text: main, systemImage: "tag")
                            Spacer(minLength: 0)
                        }
                    }

                    if vm.isEbook || vm.isEpubAvailable || vm.isPdfAvailable {
                        HStack(spacing: 6) {
                            if vm.isEbook { Chip(text: "E-Book", systemImage: "ipad.and.iphone") }
                            if vm.isEpubAvailable { Chip(text: "EPUB", systemImage: "doc.text") }
                            if vm.isPdfAvailable { Chip(text: "PDF", systemImage: "doc.richtext") }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var coverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)

            if !vm.coverCandidatesAll.isEmpty {
                CoverCandidatesImage(
                    urlStrings: vm.coverCandidatesAll,
                    preferredURLString: vm.thumbnailURL,
                    contentMode: .fill,
                    onResolvedURL: nil
                ) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    BookCoverPlaceholder(cornerRadius: 14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                BookCoverPlaceholder(cornerRadius: 14)
                    .padding(10)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 128)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Import actions

    var importActionsCard: some View {
        AddBookCard(title: "Import") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                AddBookActionTile(
                    title: "Google Books Suche",
                    subtitle: "Suchen",
                    systemImage: "magnifyingglass"
                ) {
                    vm.openImport(query: nil)
                }

                AddBookActionTile(
                    title: "ISBN Barcode",
                    subtitle: "Scannen",
                    systemImage: "barcode.viewfinder"
                ) {
                    vm.openScanner()
                }

                AddBookActionTile(
                    title: "Magie ohne Aufwand",
                    subtitle: "Inspiration",
                    systemImage: "sparkles"
                ) {
                    vm.openInspiration()
                }

                AddBookActionTile(
                    title: "Buch manuell hinzufügen",
                    subtitle: "Titel, Autor & ISBN",
                    systemImage: "square.and.pencil"
                ) {
                    vm.openManualAdd()
                }
            }
        }
    }

    // MARK: - Basics

    var basicsCard: some View {
        AddBookCard(title: "Details") {
            VStack(spacing: 12) {
                AddBookTextFieldRow(title: "Titel", systemImage: "book", text: $vm.title)

                AddBookTextFieldRow(title: "Autor", systemImage: "person", text: $vm.author)

                AddBookSubsection(title: "Status") {
                    Picker("Status", selection: $vm.status) {
                        // Use the Identifiable conformance from ReadingStatus (Book.swift)
                        // to avoid the Binding-based ForEach overload and generic inference issues.
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if vm.status == .finished {
                    AddBookSubsection(title: "Gelesen") {
                        VStack(spacing: 10) {
                            DatePicker(
                                "Von",
                                selection: $vm.readFrom,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .onChange(of: vm.readFrom) { _, newValue in
                                // Ensure readTo is never before readFrom
                                if vm.readTo < newValue {
                                    vm.readTo = newValue
                                }
                            }

                            DatePicker(
                                "Bis",
                                selection: $vm.readTo,
                                in: vm.readFrom...Date(),
                                displayedComponents: .date
                            )
                            .onChange(of: vm.readTo) { _, newValue in
                                // Ensure readFrom is never after readTo
                                if vm.readFrom > newValue {
                                    vm.readFrom = newValue
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Metadata

    var metadataCard: some View {
        AddBookCard(title: "Metadaten") {
            VStack(alignment: .leading, spacing: 14) {
                AddBookSubsection(title: "Bibliografisch") {
                    VStack(alignment: .leading, spacing: 8) {
                        AddBookMetaRow(title: "Verlag", systemImage: "building.2", value: vm.publisher)
                        AddBookMetaRow(title: "Jahr", systemImage: "calendar", value: vm.publishedYear)
                        AddBookMetaRow(title: "Seiten", systemImage: "doc.plaintext", value: vm.pageCount.map(String.init))
                        AddBookMetaRow(title: "Sprache", systemImage: "globe", value: vm.language)
                        AddBookMetaRow(title: "ISBN", systemImage: "barcode", value: vm.isbn13)
                    }
                }

                if !vm.categories.isEmpty || vm.mainCategory != nil {
                    AddBookSubsection(title: "Kategorien") {
                        let cats = vm.categories.isEmpty ? [vm.mainCategory].compactMap { $0 } : vm.categories
                        WrapChipsView(chips: cats, maxVisible: 10)
                    }
                }

                if vm.averageRating != nil || vm.ratingsCount != nil {
                    AddBookSubsection(title: "Bewertung") {
                        HStack(spacing: 10) {
                            if let r = vm.averageRating {
                                StarsView(rating: r)
                            }
                            if let c = vm.ratingsCount {
                                Text("\(c) Bewertungen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if vm.hasAvailabilityChips {
                    AddBookSubsection(title: "Verfügbarkeit") {
                        availabilityChips
                    }
                }

                if let id = vm.googleVolumeID, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AddBookSubsection(title: "IDs") {
                        AddBookMetaRow(title: "Google ID", systemImage: "tag", value: id)
                    }
                }
            }
        }
    }

    private var availabilityChips: some View {
        WrapChipsView(chips: availabilityChipItems, maxVisible: 10)
    }

    private var availabilityChipItems: [String] {
        var out: [String] = []

        if vm.isEbook { out.append("E-Book") }
        if vm.isEpubAvailable { out.append("EPUB") }
        if vm.isPdfAvailable { out.append("PDF") }
        if vm.isEmbeddable { out.append("Embeddable") }
        if vm.isPublicDomain { out.append("Public Domain") }

        if let s = vm.saleability, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(s)
        }
        if let s = vm.viewability, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(s)
        }

        return out
    }

    // MARK: - Description

    var descriptionCard: some View {
        AddBookCard(title: "Beschreibung") {
            Text(vm.trimmedDescription)
                .foregroundStyle(.secondary)
                .lineLimit(vm.isDescriptionExpanded ? nil : 6)

            if vm.trimmedDescription.count > 240 {
                Button(vm.isDescriptionExpanded ? "Weniger anzeigen" : "Mehr lesen") {
                    withAnimation(.snappy) {
                        vm.isDescriptionExpanded.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Links

    var linksCard: some View {
        AddBookCard(title: "Links") {
            if let u = vm.previewURL {
                AddBookLinkRow(title: "Vorschau", systemImage: "play.rectangle", url: u)
            }
            if let u = vm.infoURL {
                AddBookLinkRow(title: "Mehr Infos", systemImage: "safari", url: u)
            }
            if let u = vm.canonicalURL {
                AddBookLinkRow(title: "Google Books", systemImage: "book", url: u)
            }
        }
    }
}
