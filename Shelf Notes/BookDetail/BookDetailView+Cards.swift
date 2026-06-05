import SwiftUI
import SwiftData

// MARK: - Main Sections / Cards
extension BookDetailView {

    // MARK: Background

    @ViewBuilder
    var appBackground: some View {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(.systemBackground)
        #endif
    }

    // MARK: Hero (Parallax)

    var heroHeaderParallax: some View {
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

    // MARK: Cards

    var statusCard: some View {
        BookDetailCard(title: "Status") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Status", selection: statusBinding) {
                    ForEach(ReadingStatus.allCases) { status in
                        Text(status.displayName).tag(status)
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

    var sessionsCard: some View {
        SessionsCard(book: book) {
            showingAllSessionsSheet = true
        }
    }

    var readRangeCard: some View {
        BookDetailCard(title: "Gelesen") {
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
                            _ = modelContext.saveWithDiagnostics()
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
                            _ = modelContext.saveWithDiagnostics()
                        }
                    ),
                    in: (book.readFrom ?? Date.distantPast)...Date(),
                    displayedComponents: [.date]
                )
            }
        }
    }

    var ratingSummaryCard: some View {
        BookDetailCard(title: "Deine Bewertung") {
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

    var ratingLockedCard: some View {
        BookDetailCard(title: "Bewertung") {
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

    var notesPreviewCard: some View {
        BookDetailCard(title: "Notizen") {
            Button {
                presentNotesEditor()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    if notesMetrics.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "square.and.pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lesenotiz starten")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("Halte Gedanken, Zitate und Aha-Momente fest. Ein bisschen Buch-Therapie schadet nie.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(notesMetrics.previewText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(4)

                        Label(notesMetrics.summaryLine, systemImage: "text.alignleft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()
                        Text(notesMetrics.isEmpty ? "Notiz starten" : "Notiz bearbeiten")
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

    var tagsCard: some View {
        let autocompleteSuggestions = tagAutocompleteSuggestions
        let suggestionState = tagSuggestionViewState

        return BookDetailCard(title: "Tags") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    TagSectionHeader(
                        "Aktuelle Tags",
                        subtitle: book.tags.isEmpty ? "Noch keine Tags gesetzt." : "Tippe auf das x, um einen Tag zu entfernen."
                    )

                    if book.tags.isEmpty {
                        Text("Tags helfen dir später beim Finden, Sortieren und Aufräumen deiner Bibliothek.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
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
                }

                VStack(alignment: .leading, spacing: 8) {
                    TagSectionHeader("Neuen Tag eingeben")

                    TextField("Tag hinzufügen", text: $tagDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { addTagsFromDraft() }
                        .onChange(of: tagDraft) { _, newValue in
                            if newValue.contains(",") {
                                addTagsFromDraft()
                            }
                        }
                }

                if !autocompleteSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        TagSectionHeader("Passend zur Eingabe")

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(autocompleteSuggestions, id: \.self) { suggestion in
                                TagSuggestionPill(text: suggestion) {
                                    acceptTagSuggestion(suggestion)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if tagDraftQuery.isEmpty {
                    if !suggestionState.smartItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            TagSectionHeader(
                                "Vorgeschlagen für dieses Buch",
                                subtitle: "Aus Kategorien, ähnlichen Büchern und gemeinsamen Tags."
                            )

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 148), spacing: 8)],
                                spacing: 8
                            ) {
                                ForEach(suggestionState.smartItems) { item in
                                    SmartTagSuggestionButton(item: item) {
                                        acceptTagSuggestion(item.tag)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } else if !book.categories.isEmpty || book.mainCategory != nil {
                        Text("Für dieses Buch gibt es gerade keine neuen Tag-Vorschläge. Deine gesetzten Tags und Kategorien sind schon gut abgedeckt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !suggestionState.frequentItems.isEmpty {
                    Divider().opacity(0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        TagSectionHeader(
                            "Häufig verwendet",
                            subtitle: "Tippen fügt hinzu oder entfernt den Tag wieder."
                        )

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(suggestionState.frequentItems) { item in
                                TagPickPill(
                                    text: item.tag,
                                    count: item.count,
                                    isSelected: item.isSelected,
                                    onTap: { toggleTag(item.tag) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } else if tagsIndexStore.tagCounts.isEmpty {
                    Text("Noch keine häufigen Tags vorhanden. Sobald du mehr Bücher taggst, tauchen hier Schnellzugriffe auf.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var collectionsPreviewCard: some View {
        BookDetailCard(title: "Listen") {
            Button {
                showingCollectionsSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    let names = book.collectionsSafe
                        .map { $0.name }
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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

    var moreInfoCard: some View {
        BookDetailCard(title: "Mehr") {
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

    // MARK: Bottom bar (3 actions)

    var bottomActionBar: some View {
        BottomActionBar(
            status: statusBinding,
            onNote: { presentNotesEditor() },
            onCollections: { showingCollectionsSheet = true }
        )
    }
}
