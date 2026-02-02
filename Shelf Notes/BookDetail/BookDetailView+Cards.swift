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

    var tagsCard: some View {
        BookDetailCard(title: "Tags") {
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

                if !tagAutocompleteSuggestions.isEmpty {
                    Text("Vorschläge")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(tagAutocompleteSuggestions, id: \.self) { suggestion in
                            TagSuggestionPill(text: suggestion) {
                                acceptTagSuggestion(suggestion)
                            }
                        }
                    }
                    .padding(.vertical, 2)
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
            onNote: { showingNotesSheet = true },
            onCollections: { showingCollectionsSheet = true }
        )
    }
}
