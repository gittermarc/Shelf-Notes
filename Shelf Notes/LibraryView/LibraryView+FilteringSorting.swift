//
//  LibraryView+FilteringSorting.swift
//  Shelf Notes
//
//  Sorting helpers that stay view-facing; filtering/sorting itself lives in LibraryDerivedStateBuilder.
//

import Foundation

extension LibraryView {

    // MARK: - Sorting

    enum SortField: String, CaseIterable, Identifiable, Hashable {
        case createdAt = "Hinzugefügt"
        case readDate = "Gelesen"
        case rating = "Bewertung"
        case title = "Titel"
        case author = "Autor"

        var id: String { rawValue }
    }

    var sortField: SortField {
        get { SortField(rawValue: sortFieldRaw) ?? .createdAt }
        nonmutating set { sortFieldRaw = newValue.rawValue }
    }

    func bestTitle(_ book: Book) -> String {
        let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Titel" : trimmed
    }
}
