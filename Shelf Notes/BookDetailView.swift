//
//  BookDetailView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//  Apple-Books-ish redesign on 05.01.26.
//  Parallax header + Apple-style toolbar on 05.01.26.
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

// MARK: - Detail
struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book

    @State private var tagsText: String = ""
    @State private var tagDraft: String = ""

    // Cover upload (user photo)
    #if canImport(PhotosUI)
    @State private var pickedCoverItem: PhotosPickerItem?
    @State private var showingPhotoPicker: Bool = false
    #endif
    @State private var isUploadingCover: Bool = false
    @State private var coverUploadError: String? = nil

    // Online cover picker
    @State private var showingOnlineCoverPicker: Bool = false

    // NavBar title reveal after header scroll
    @State private var showCompactNavTitle: Bool = false

    // ✅ Collections
    @Query(sort: \BookCollection.name, order: .forward)
    private var allCollections: [BookCollection]

    // ✅ Für Top-Tags: alle Bücher laden
    @Query private var allBooks: [Book]

    @State private var showingNewCollectionSheet = false
    @State private var showingPaywall = false

    // Apple-Books-ish UX sheets
    @State private var showingNotesSheet = false
    @State private var showingCollectionsSheet = false
    @State private var showingRatingSheet = false

    @State private var isDescriptionExpanded = false
    @State private var isMoreInfoExpanded = false

    // ✅ Reading Sessions (Quick-Log + per-book list)
    @State private var showingAllSessionsSheet: Bool = false

    // Toolbar actions
    @State private var showingDeleteConfirm = false
    #if canImport(UIKit)
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    #endif

    @EnvironmentObject private var pro: ProManager

    // MARK: - Bindings (Compiler-friendly)

    private var statusBinding: Binding<ReadingStatus> {
        Binding(
            get: { book.status },
            set: { newStatus in
                book.status = newStatus

                if newStatus == .finished {
                    if book.readFrom == nil { book.readFrom = Date() }
                    if book.readTo == nil { book.readTo = book.readFrom }
                }
                try? modelContext.save()
            }
        )
    }

    private func membershipBinding(for col: BookCollection) -> Binding<Bool> {
        Binding(
            get: { book.isInCollection(col) },
            set: { isOn in
                setMembership(isOn, for: col)
            }
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroHeaderParallax

                QuickChipsRow(
                    overallRating: displayedOverallRating,
                    overallText: displayedOverallRatingText,
                    showsUserBadge: hasUserRating,
                    pageCount: book.pageCount,
                    publishedDate: book.publishedDate,
                    language: book.language
                )

                statusCard

                sessionsCard

                if book.status == .finished {
                    readRangeCard
                    ratingSummaryCard
                } else {
                    ratingLockedCard
                }

                notesPreviewCard
                tagsCard
                collectionsPreviewCard

                moreInfoCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 18) // breathing room above bottom bar
        }
        .coordinateSpace(name: "BookDetailScroll")
        .background(appBackground)
        .navigationTitle(showCompactNavTitle ? "" : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .onPreferenceChange(HeaderMinYPreferenceKey.self) { minY in
            let threshold: CGFloat = -160
            let shouldShow = minY < threshold
            if shouldShow != showCompactNavTitle {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showCompactNavTitle = shouldShow
                }
            }
        }
        .confirmationDialog(
            "Buch wirklich löschen?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                deleteBook()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .sheet(isPresented: $showingNotesSheet) {
            NotesEditorSheet(notes: $book.notes) {
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingCollectionsSheet) {
            CollectionsPickerSheet(
                allCollections: allCollections,
                membershipBinding: membershipBinding(for:),
                onCreateNew: { requestNewCollection() }
            )
        }
        .sheet(isPresented: $showingRatingSheet) {
            RatingEditorSheet(
                book: book,
                onReset: { resetUserRating() },
                onSave: { try? modelContext.save() }
            )
        }
        .sheet(isPresented: $showingAllSessionsSheet) {
            AllSessionsListSheet(book: book)
        }
        .sheet(isPresented: $showingNewCollectionSheet) {
            InlineNewCollectionSheet { name in
                createAndAttachCollection(named: name)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(onPurchased: {
                showingNewCollectionSheet = true
            })
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: shareItems)
        }
        #endif
        .sheet(isPresented: $showingOnlineCoverPicker) {
            OnlineCoverPickerSheet(
                candidates: book.coverURLCandidates,
                selectedURLString: book.thumbnailURL,
                onSelect: { s in
                    Task { @MainActor in
                        await CoverThumbnailer.applyRemoteCover(urlString: s, to: book, modelContext: modelContext)
                    }
                }
            )
        }
        #if canImport(PhotosUI)
        .modifier(PhotoPickerPresenter(isPresented: $showingPhotoPicker, selection: $pickedCoverItem))
        #endif

        .onAppear {
            tagsText = book.tags.joined(separator: ", ")
            tagDraft = ""
        }
        #if canImport(PhotosUI)
        .onChange(of: pickedCoverItem) { _, newValue in
            handlePickedCoverItem(newValue)
        }
        #endif
        .onDisappear {
            try? modelContext.save()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
    private var coverChangeMenuItems: some View {
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

    private var compactNavTitle: String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Ohne Titel" : t
    }

    private var compactNavSubtitle: String {
        book.author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shareSubject: String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Buch" : t
    }

    private var shareMessage: String {
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

    private var shareURLCandidate: URL? {
        // Prefer canonical/info/preview links if available
        if let u = urlFromString(book.canonicalVolumeLink) { return u }
        if let u = urlFromString(book.infoLink) { return u }
        if let u = urlFromString(book.previewLink) { return u }
        return nil
    }

    private func presentShare(items: [Any]) {
        #if canImport(UIKit)
        shareItems = items
        showingShareSheet = true
        #endif
    }

    // MARK: - Background

    private var appBackground: some View {
        #if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(.systemBackground)
        #endif
    }

    // MARK: - Hero (Parallax)

    private var heroHeaderParallax: some View {
        BookHeroHeaderParallax(
            book: book,
            hasUserRating: hasUserRating,
            displayedOverallRating: displayedOverallRating,
            displayedOverallText: displayedOverallRatingText,
            baseHeight: 240,
            coordinateSpaceName: "BookDetailScroll"
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HeaderMinYPreferenceKey.self,
                    value: geo.frame(in: .named("BookDetailScroll")).minY
                )
            }
        )
    }

    // MARK: - Cards

    private var statusCard: some View {
        DetailCard(title: "Status") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Status", selection: statusBinding) {
                    ForEach(ReadingStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                if let err = coverUploadError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if isUploadingCover {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Cover wird verarbeitet …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var sessionsCard: some View {
        SessionsCard(book: book) {
            showingAllSessionsSheet = true
        }
    }

    private var readRangeCard: some View {
        DetailCard(title: "Gelesen") {
            VStack(alignment: .leading, spacing: 12) {
                if let readLine = formattedReadRangeLine(from: book.readFrom, to: book.readTo) {
                    Text(readLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    "Von",
                    selection: Binding(
                        get: { book.readFrom ?? Date() },
                        set: { newValue in
                            book.readFrom = newValue
                            if let to = book.readTo, to < newValue { book.readTo = newValue }
                            try? modelContext.save()
                        }
                    ),
                    displayedComponents: [.date]
                )

                DatePicker(
                    "Bis",
                    selection: Binding(
                        get: { book.readTo ?? (book.readFrom ?? Date()) },
                        set: { newValue in
                            book.readTo = newValue
                            if let from = book.readFrom, from > newValue { book.readFrom = newValue }
                            try? modelContext.save()
                        }
                    ),
                    in: (book.readFrom ?? Date.distantPast)...Date(),
                    displayedComponents: [.date]
                )
            }
        }
    }

    private var ratingSummaryCard: some View {
        DetailCard(title: "Deine Bewertung") {
            Button {
                showingRatingSheet = true
            } label: {
                HStack(spacing: 12) {
                    if let avg = book.userRatingAverage1 {
                        StarsView(rating: avg)
                        Text(String(format: "%.1f", avg) + " / 5")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Image(systemName: "star")
                            .foregroundStyle(.secondary)
                        Text("Noch nicht bewertet")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Tippe, um Handlung/Charaktere/Schreibstil & Co. zu bewerten.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var ratingLockedCard: some View {
        DetailCard(title: "Bewertung") {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.secondary)
                Text("Bewertungen sind erst möglich, wenn der Status auf „Gelesen“ steht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var notesPreviewCard: some View {
        DetailCard(title: "Notizen") {
            Button {
                showingNotesSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    if book.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Tippe, um eine Notiz zu schreiben …")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(book.notes)
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                    }

                    HStack {
                        Spacer()
                        Text("Bearbeiten")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var tagsCard: some View {
        DetailCard(title: "Tags") {
            VStack(alignment: .leading, spacing: 10) {
                if !book.tags.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(book.tags, id: \.self) { t in
                            SelectedTagPill(text: t) { removeTag(t) }
                        }
                    }
                    .padding(.vertical, 2)
                }

                TextField("Tag hinzufügen …", text: $tagDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { addTagsFromDraft() }
                    .onChange(of: tagDraft) { _, newValue in
                        if newValue.contains(",") {
                            addTagsFromDraft()
                        }
                    }

                if !topTagCounts30.isEmpty {
                    Divider().opacity(0.5)

                    Text("Häufige Tags (Tippen = hinzufügen/entfernen)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(topTagCounts30, id: \.tag) { entry in
                            TagPickPill(
                                text: entry.tag,
                                count: entry.count,
                                isSelected: isTagSelected(entry.tag),
                                onTap: { toggleTag(entry.tag) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var collectionsPreviewCard: some View {
        DetailCard(title: "Listen") {
            Button {
                showingCollectionsSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    let names = book.collectionsSafe.map { $0.name }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if names.isEmpty {
                        Text("Noch in keiner Liste")
                            .foregroundStyle(.secondary)
                    } else {
                        WrapChipsView(
                            chips: names,
                            maxVisible: 6
                        )
                    }

                    HStack {
                        Spacer()
                        Text("Bearbeiten")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var moreInfoCard: some View {
        DetailCard(title: "Mehr") {
            DisclosureGroup(isExpanded: $isMoreInfoExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    // Bibliophile infos (links, availability, google rating, cover candidates)
                    if hasAnyBibliophileInfo {
                        bibliophileBlock
                    }

                    metadataBlock
                    descriptionBlock
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Infos, Metadaten & Beschreibung")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var bibliophileBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasAnyLinks {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        if let url = urlFromString(book.previewLink) {
                            PrettyLinkRow(title: "Leseprobe / Vorschau", url: url, systemImage: "book.pages")
                        }
                        if let url = urlFromString(book.infoLink) {
                            PrettyLinkRow(title: "Info-Seite", url: url, systemImage: "info.circle")
                        }
                        if let url = urlFromString(book.canonicalVolumeLink) {
                            PrettyLinkRow(title: "Original bei Google Books", url: url, systemImage: "link")
                        }
                    }
                } label: {
                    Label("Online ansehen", systemImage: "safari")
                }
            }

            if hasAnyAvailability {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        if let viewability = prettyViewability {
                            LabeledContent("Vorschauumfang", value: viewability)
                        }

                        LabeledContent("EPUB") { availabilityLabel(book.isEpubAvailable) }
                        LabeledContent("PDF") { availabilityLabel(book.isPdfAvailable) }

                        if let sale = prettySaleability {
                            LabeledContent("Kaufstatus", value: sale)
                        }

                        LabeledContent("E-Book") { boolLabel(book.isEbook, trueText: "Ja", falseText: "Nein") }
                        LabeledContent("Einbettbar") { boolIcon(book.isEmbeddable) }
                        LabeledContent("Public Domain") { boolIcon(book.isPublicDomain) }
                    }
                } label: {
                    Label("Formate & Verfügbarkeit", systemImage: "doc.on.doc")
                }
            }

            if hasRating {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            StarsView(rating: book.averageRating ?? 0)
                            Text(ratingText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                        }

                        Text("Hinweis: Bewertungen können je nach Buch/Edition stark variieren.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Google-Bewertungen", systemImage: "star.bubble")
                }
            }

            if !book.coverURLCandidates.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tippe ein Cover an, um es als Standardcover zu setzen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(book.coverURLCandidates, id: \.self) { s in
                                    Button {
                                        let current = (book.thumbnailURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                        let isSame = current.caseInsensitiveCompare(s) == .orderedSame
                                        guard !isSame else { return }

                                        Task { @MainActor in
                                            await CoverThumbnailer.applyRemoteCover(urlString: s, to: book, modelContext: modelContext)
                                        }
                                    } label: {
                                        CoverThumb(
                                            urlString: s,
                                            isSelected: ((book.thumbnailURL ?? "").caseInsensitiveCompare(s) == .orderedSame)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } label: {
                    Label("Cover auswählen", systemImage: "photo.on.rectangle")
                }
            }
        }
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metadaten")
                .font(.subheadline.weight(.semibold))

            if let isbn = book.isbn13, !isbn.isEmpty {
                LabeledContent("ISBN 13", value: isbn)
            }
            if let publisher = book.publisher, !publisher.isEmpty {
                LabeledContent("Verlag", value: publisher)
            }
            if let publishedDate = book.publishedDate, !publishedDate.isEmpty {
                LabeledContent("Erschienen", value: publishedDate)
            }
            if let pageCount = book.pageCount {
                LabeledContent("Seiten", value: "\(pageCount)")
            }
            if let language = book.language, !language.isEmpty {
                LabeledContent("Sprache", value: language)
            }

            if let main = book.mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
               !main.isEmpty {
                LabeledContent("Hauptkategorie", value: main)
            }

            if !book.categories.isEmpty {
                Text("Kategorien: \(book.categories.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var descriptionBlock: some View {
        let desc = book.bookDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 10) {
            if !desc.isEmpty {
                Text("Beschreibung")
                    .font(.subheadline.weight(.semibold))

                Text(desc)
                    .foregroundStyle(.secondary)
                    .lineLimit(isDescriptionExpanded ? nil : 6)

                Button(isDescriptionExpanded ? "Weniger" : "Mehr anzeigen") {
                    withAnimation(.snappy) { isDescriptionExpanded.toggle() }
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    // MARK: - Bottom bar (3 actions)

    private var bottomActionBar: some View {
        BottomActionBar(
            status: statusBinding,
            onNote: { showingNotesSheet = true },
            onCollections: { showingCollectionsSheet = true }
        )
    }

    // MARK: - Bibliophile computed properties

    private var hasAnyLinks: Bool {
        (book.previewLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.infoLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.canonicalVolumeLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    private var hasAnyAvailability: Bool {
        (book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isPublicDomain
        || book.isEmbeddable
        || book.isEpubAvailable
        || book.isPdfAvailable
        || (book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isEbook
    }

    private var hasRating: Bool {
        if let avg = book.averageRating, avg > 0 { return true }
        return false
    }

    private var ratingText: String {
        let avg = book.averageRating ?? 0
        let count = book.ratingsCount ?? 0
        if count > 0 {
            return String(format: "%.1f", avg) + " (\(count))"
        }
        return String(format: "%.1f", avg)
    }

    private var hasUserRating: Bool {
        book.userRatingAverage != nil
    }

    private var hasAnyUserRatingValue: Bool {
        book.userRatingValues.contains(where: { $0 > 0 })
    }

    private var displayedOverallRating: Double? {
        if let u = book.userRatingAverage1 { return u }
        if let g = book.averageRating, g > 0 { return g }
        return nil
    }

    private var displayedOverallRatingText: String {
        if let u = book.userRatingAverage1 {
            return String(format: "%.1f", u) + " / 5"
        }
        return ratingText
    }

    private func resetUserRating() {
        book.userRatingPlot = 0
        book.userRatingCharacters = 0
        book.userRatingWritingStyle = 0
        book.userRatingAtmosphere = 0
        book.userRatingGenreFit = 0
        book.userRatingPresentation = 0
        try? modelContext.save()
    }

    private var prettyViewability: String? {
        guard let v = book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty else { return nil }

        switch v.uppercased() {
        case "NO_PAGES": return "Keine Vorschau"
        case "PARTIAL": return "Teilansicht"
        case "ALL_PAGES": return "Vollansicht"
        case "UNKNOWN": return "Unbekannt"
        default: return v
        }
    }

    private var prettySaleability: String? {
        guard let s = book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }

        switch s.uppercased() {
        case "FOR_SALE": return "Käuflich"
        case "NOT_FOR_SALE": return "Nicht käuflich"
        case "FREE": return "Kostenlos"
        case "FOR_PREORDER": return "Vorbestellbar"
        default: return s
        }
    }

    private var hasAnyBibliophileInfo: Bool {
        hasAnyLinks || hasAnyAvailability || hasRating || !book.coverURLCandidates.isEmpty
    }

    // MARK: - Cover upload helpers

    #if canImport(PhotosUI)
    private func handlePickedCoverItem(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isUploadingCover = true
        coverUploadError = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(domain: "CoverUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Konnte Bilddaten nicht laden."])
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

    private func removeUserCover() {
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }
        book.userCoverFileName = nil
        book.userCoverData = nil
        try? modelContext.save()

        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
        }
    }

    // MARK: - Delete

    private func deleteBook() {
        // Clean up local user cover file if any
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }

        modelContext.delete(book)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Tags

    private var topTagCounts30: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]

        for b in allBooks {
            for t in b.tags {
                let n = normalizeTagString(t)
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }

        let sorted = counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
            }

        return Array(sorted.prefix(30))
    }

    private func isTagSelected(_ tag: String) -> Bool {
        let n = normalizeTagString(tag)
        return book.tags.contains { normalizeTagString($0).caseInsensitiveCompare(n) == .orderedSame }
    }

    private func toggleTag(_ tag: String) {
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
        try? modelContext.save()
    }

    private func addTagsFromDraft() {
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
        try? modelContext.save()
    }

    private func removeTag(_ tag: String) {
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
        try? modelContext.save()
    }

    private func parseTags(_ input: String) -> [String] {
        let raw = input
            .split(separator: ",")
            .map { normalizeTagString(String($0)) }
            .filter { !$0.isEmpty }

        var out: [String] = []
        for t in raw {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }
        return out
    }

    // MARK: - Read range

    private func formattedReadRangeLine(from: Date?, to: Date?) -> String? {
        guard from != nil || to != nil else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        if let from, let to {
            return "Gelesen: \(df.string(from: from)) – \(df.string(from: to))"
        } else if let from {
            return "Gelesen ab: \(df.string(from: from))"
        } else if let to {
            return "Gelesen bis: \(df.string(from: to))"
        }
        return nil
    }

    // MARK: - Collections helpers

    private func requestNewCollection() {
        let count = allCollections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNewCollectionSheet = true
        } else {
            showingPaywall = true
        }
    }

    private func setMembership(_ isMember: Bool, for collection: BookCollection) {
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

        try? modelContext.save()
    }

    private func createAndAttachCollection(named name: String) {
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

    private func urlFromString(_ s: String?) -> URL? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private func availabilityLabel(_ ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .secondary)
            Text(ok ? "verfügbar" : "nicht verfügbar")
                .foregroundStyle(.secondary)
        }
    }

    private func boolIcon(_ ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(ok ? .green : .secondary)
    }

    private func boolLabel(_ ok: Bool, trueText: String, falseText: String) -> some View {
        Text(ok ? trueText : falseText)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Scroll / NavBar Helpers

private struct HeaderMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if canImport(PhotosUI)
private struct PhotoPickerPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selection: PhotosPickerItem?

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .photosPicker(isPresented: $isPresented, selection: $selection, matching: .images)
        } else {
            // Fallback: PhotosPicker in a sheet for older iOS versions
            content
                .sheet(isPresented: $isPresented) {
                    PhotosPicker(selection: $selection, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Fotos auswählen")
                                .font(.headline)
                        }
                        .padding(24)
                    }
                    .padding()
                }
        }
    }
}
#endif

private struct OnlineCoverPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let candidates: [String]
    let selectedURLString: String?
    let onSelect: (String) -> Void

    private var selectedNormalized: String {
        (selectedURLString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tippe ein Cover an, um es zu setzen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(candidates, id: \.self) { s in
                            Button {
                                onSelect(s)
                                dismiss()
                            } label: {
                                CoverThumb(
                                    urlString: s,
                                    isSelected: selectedNormalized == s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Online-Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}



// MARK: - Apple-Books-ish UI Components

private struct BookHeroHeaderParallax: View {
    @Bindable var book: Book
    let hasUserRating: Bool
    let displayedOverallRating: Double?
    let displayedOverallText: String

    let baseHeight: CGFloat
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(coordinateSpaceName)).minY
            let stretch = max(minY, 0)
            let height = baseHeight + stretch

            ZStack(alignment: .bottomLeading) {
                // Background: big cover + blur + gradient
                BookCoverThumbnailView(
                    book: book,
                    size: CGSize(width: geo.size.width, height: height),
                    cornerRadius: 22
                )
                .scaledToFill()
                .frame(width: geo.size.width, height: height)
                .clipped()
                .blur(radius: 18)
                .scaleEffect(stretch > 0 ? (1.0 + (stretch / 700.0)) : 1.0)
                .overlay(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.35),
                            .black.opacity(0.10),
                            .black.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .offset(y: stretch > 0 ? -stretch : 0) // keep top anchored while stretching

                // Foreground content
                HStack(alignment: .bottom, spacing: 14) {
                    BookCoverThumbnailView(
                        book: book,
                        size: CGSize(width: 120, height: 180),
                        cornerRadius: 16
                    )
                    .shadow(radius: 12, y: 6)
                    .offset(y: stretch > 0 ? (-stretch * 0.15) : 0) // subtle parallax

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)

                        let a = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(a.isEmpty ? "—" : a)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)

                        if let overall = displayedOverallRating {
                            HStack(spacing: 10) {
                                StarsView(rating: overall)

                                Text(displayedOverallText)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .monospacedDigit()

                                if hasUserRating {
                                    Text("deins")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .offset(y: stretch > 0 ? (-stretch * 0.10) : (minY < 0 ? (minY * 0.08) : 0)) // gentle parallax
            }
        }
        .frame(height: baseHeight)
    }
}

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct BottomActionBar: View {
    @Binding var status: ReadingStatus
    let onNote: () -> Void
    let onCollections: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Status", selection: $status) {
                    ForEach(ReadingStatus.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
            } label: {
                Label("Status", systemImage: "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: onNote) {
                Label("Notiz", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: onCollections) {
                Label("Liste", systemImage: "text.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.primary.opacity(0.06)),
            alignment: .top
        )
    }
}

private struct QuickChipsRow: View {
    let overallRating: Double?
    let overallText: String
    let showsUserBadge: Bool

    let pageCount: Int?
    let publishedDate: String?
    let language: String?

    var body: some View {
        HStack(spacing: 8) {
            if let r = overallRating {
                Chip(text: overallText, systemImage: "star.fill")
            }

            if let pc = pageCount {
                Chip(text: "\(pc) S.", systemImage: "doc.plaintext")
            }

            if let y = publishedYear(publishedDate) {
                Chip(text: y, systemImage: "calendar")
            }

            if let lang = language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty {
                Chip(text: lang.uppercased(), systemImage: "globe")
            }

            Spacer()
        }
    }

    private func publishedYear(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Accept "YYYY" or "YYYY-MM-DD"
        if s.count >= 4 {
            let y = String(s.prefix(4))
            if Int(y) != nil { return y }
        }
        return nil
    }
}

private struct Chip: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}

private struct WrapChipsView: View {
    let chips: [String]
    var maxVisible: Int = 6

    var body: some View {
        let visible = Array(chips.prefix(maxVisible))
        let remaining = max(0, chips.count - visible.count)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(visible, id: \.self) { c in
                Text(c)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct NotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $notes)
                    .padding(12)
            }
            .navigationTitle("Notiz")
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
}

private struct CollectionsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allCollections: [BookCollection]
    let membershipBinding: (BookCollection) -> Binding<Bool>
    let onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if allCollections.isEmpty {
                    Text("Noch keine Listen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allCollections) { col in
                        Toggle(isOn: membershipBinding(col)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(col.name.isEmpty ? "Ohne Namen" : col.name)
                                Text("\(col.booksSafe.count) Bücher")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        onCreateNew()
                    } label: {
                        Label("Neue Liste …", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Listen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Small UI Components (existing)

private struct PrettyLinkRow: View {
    let title: String
    let url: URL
    let systemImage: String

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)

                    Text(prettyHost(url))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func prettyHost(_ url: URL) -> String {
        if let host = url.host, !host.isEmpty { return host }
        return url.absoluteString
    }
}

private struct CoverThumb: View {
    let urlString: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(0.12)

            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BookCoverPlaceholder(cornerRadius: 10)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(lineWidth: 2)
                    .foregroundStyle(.primary.opacity(0.35))
            }
        }
        .frame(width: 56, height: 84)
        .clipped()
    }
}

// MARK: - Reading Sessions UI (Quick-Log + Lists)

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif
