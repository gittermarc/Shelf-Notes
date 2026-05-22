import SwiftUI

extension AddBookView {
    var taggingCard: some View {
        AddBookCard(title: "Tags") {
            VStack(alignment: .leading, spacing: 12) {
                AddBookSubsection(title: "Aktuelle Tags") {
                    if vm.tags.isEmpty {
                        Text("Optional, aber praktisch: Tags machen das Buch später leichter auffindbar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(vm.tags, id: \.self) { tag in
                                SelectedTagPill(text: tag) {
                                    vm.removeTag(tag)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                AddBookSubsection(title: "Neuen Tag eingeben") {
                    TextField("Tag hinzufügen", text: $vm.tagDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { vm.addTagsFromDraft() }
                        .onChange(of: vm.tagDraft) { _, newValue in
                            if newValue.contains(",") {
                                vm.addTagsFromDraft()
                            }
                        }
                }

                if !addBookAutocompleteSuggestions.isEmpty {
                    AddBookSubsection(title: "Passend zur Eingabe") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(addBookAutocompleteSuggestions, id: \.self) { suggestion in
                                TagSuggestionPill(text: suggestion) {
                                    vm.acceptTagSuggestion(suggestion)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if vm.tagDraftQuery.isEmpty {
                    if !addBookSmartSuggestionItems.isEmpty {
                        AddBookSubsection(title: "Vorgeschlagen für dieses Buch") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Aus Kategorien, ähnlichen Büchern und deiner vorhandenen Bibliothek.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 148), spacing: 8)],
                                    spacing: 8
                                ) {
                                    ForEach(addBookSmartSuggestionItems) { item in
                                        SmartTagSuggestionButton(item: item) {
                                            vm.acceptTagSuggestion(item.tag)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } else if !vm.categories.isEmpty || vm.mainCategory != nil {
                        Text("Aus den importierten Kategorien entsteht gerade kein neuer sinnvoller Tag-Vorschlag.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !addBookFrequentTagItems.isEmpty {
                    Divider().opacity(0.5)

                    AddBookSubsection(title: "Häufig verwendet") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(addBookFrequentTagItems) { item in
                                TagPickPill(
                                    text: item.tag,
                                    count: item.count,
                                    isSelected: item.isSelected,
                                    onTap: { vm.toggleTag(item.tag) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } else if tagsIndexStore.tagCounts.isEmpty {
                    Text("Noch keine bestehenden Tags vorhanden. Dieses Buch kann der Anfang deiner Tag-Struktur werden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var addBookAutocompleteSuggestions: [String] {
        TagsIndexBuilder.autocompleteSuggestions(
            query: vm.tagDraftQuery,
            selectedTags: vm.tags,
            tagCounts: tagsIndexStore.tagCounts
        )
    }

    var addBookSmartSuggestionItems: [TagSuggestionDisplayItem] {
        let target = vm.tagSuggestionSnapshot()
        let library = TagSuggestionEngine.makeSnapshots(books: allBooks)
        let suggestions = TagSuggestionEngine.suggestions(
            for: target,
            in: library,
            limit: 8
        )

        return TagSuggestionPresentationBuilder.suggestedItems(
            from: suggestions,
            selectedTags: vm.tags,
            limit: 6
        )
    }

    var addBookFrequentTagItems: [FrequentTagDisplayItem] {
        TagSuggestionPresentationBuilder.frequentItems(
            from: tagsIndexStore.tagCounts,
            selectedTags: vm.tags,
            excludingTags: addBookSmartSuggestionItems.map(\.tag),
            limit: 18
        )
    }
}
