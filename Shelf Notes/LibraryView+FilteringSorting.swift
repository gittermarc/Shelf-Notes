//
//  LibraryView+FilteringSorting.swift
//  Shelf Notes
//
//  Extracted from LibraryView.swift to reduce file size and improve maintainability.
//

import SwiftUI
import Foundation

extension LibraryView {

    // MARK: Sorting

    enum SortField: String, CaseIterable, Identifiable {
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

    // MARK: Filtering + Sorting

    var filteredBooks: [Book] {
        books.filter { book in
            if let selectedStatus, book.status != selectedStatus { return false }

            if let selectedTag, !book.tags.contains(where: { $0.caseInsensitiveCompare(selectedTag) == .orderedSame }) {
                return false
            }

            if onlyWithNotes {
                if book.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            }

            let s = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty {
                let hay = [
                    book.title,
                    book.author,
                    book.isbn13 ?? "",
                    book.tags.joined(separator: " ")
                ].joined(separator: " ").lowercased()

                if !hay.contains(s.lowercased()) { return false }
            }

            return true
        }
    }

    var displayedBooks: [Book] {
        sortBooks(filteredBooks)
    }

    func sortBooks(_ input: [Book]) -> [Book] {
        switch sortField {
        case .createdAt:
            return input.sorted { a, b in
                if a.createdAt != b.createdAt {
                    return sortAscending ? (a.createdAt < b.createdAt) : (a.createdAt > b.createdAt)
                }
                return a.id.uuidString < b.id.uuidString
            }

        case .readDate:
            // Sort by readTo/readFrom for finished books.
            // Books without a read date fall back to createdAt, and we prefer "has read date" first.
            return input.sorted { a, b in
                let aRead = readKeyDate(a)
                let bRead = readKeyDate(b)

                let aHas = aRead != nil
                let bHas = bRead != nil

                if aHas != bHas {
                    // Prefer read-dated books first (so "Gelesen" sort is meaningful)
                    return aHas && !bHas
                }

                let da = aRead ?? a.createdAt
                let db = bRead ?? b.createdAt

                if da != db {
                    return sortAscending ? (da < db) : (da > db)
                }
                return a.id.uuidString < b.id.uuidString
            }

        case .rating:
            // User rating (only for finished books). Unrated books sink to the bottom.
            return input.sorted { a, b in
                let ar: Double? = (a.status == .finished) ? a.userRatingAverage1 : nil
                let br: Double? = (b.status == .finished) ? b.userRatingAverage1 : nil

                let aHas = ar != nil
                let bHas = br != nil

                if aHas != bHas {
                    // Prefer rated books first so sorting is meaningful.
                    return aHas && !bHas
                }

                let ra = ar ?? -1
                let rb = br ?? -1

                if ra != rb {
                    return sortAscending ? (ra < rb) : (ra > rb)
                }

                // Tie-breakers
                let da = readKeyDate(a) ?? a.createdAt
                let db = readKeyDate(b) ?? b.createdAt
                if da != db { return da > db }
                return a.id.uuidString < b.id.uuidString
            }

        case .title:
            return input.sorted { a, b in
                let ta = bestTitle(a)
                let tb = bestTitle(b)
                let cmp = ta.localizedCaseInsensitiveCompare(tb)
                if cmp != .orderedSame {
                    return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }
                return a.createdAt > b.createdAt
            }

        case .author:
            return input.sorted { a, b in
                let aa = a.author.trimmingCharacters(in: .whitespacesAndNewlines)
                let ab = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
                let sa = aa.isEmpty ? "—" : aa
                let sb = ab.isEmpty ? "—" : ab
                let cmp = sa.localizedCaseInsensitiveCompare(sb)
                if cmp != .orderedSame {
                    return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }

                let ta = bestTitle(a)
                let tb = bestTitle(b)
                let cmp2 = ta.localizedCaseInsensitiveCompare(tb)
                if cmp2 != .orderedSame {
                    return cmp2 == .orderedAscending
                }
                return a.createdAt > b.createdAt
            }
        }
    }

    func readKeyDate(_ book: Book) -> Date? {
        guard book.status == .finished else { return nil }
        return book.readTo ?? book.readFrom
    }

    func bestTitle(_ book: Book) -> String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Ohne Titel" : t
    }

    // A–Z hint logic (only show when it’s actually helpful)
    var shouldShowAlphaIndexHint: Bool {
        libraryLayoutMode == .list && sortField == .title && displayedBooks.count >= Self.alphaIndexHintThreshold
    }
}
