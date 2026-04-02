//
//  LibraryDerivedStateBuilder.swift
//  Shelf Notes
//
//  Pure builder for filtering, sorting, counts and alpha sections in the library.
//

import Foundation

extension LibraryView {

    nonisolated enum LibraryDerivedStateBuilder {

        static func makeInput(
            searchText: String,
            selectedStatus: ReadingStatus?,
            selectedTag: String?,
            onlyWithNotes: Bool,
            sortField: SortField,
            sortAscending: Bool,
            buildsAlphaSections: Bool
        ) -> LibraryDerivedInput {
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedSelectedTag = selectedTag?.trimmingCharacters(in: .whitespacesAndNewlines)

            return LibraryDerivedInput(
                searchText: trimmedSearch,
                selectedStatusRawValue: selectedStatus?.rawValue,
                selectedTag: normalizedSelectedTag,
                onlyWithNotes: onlyWithNotes,
                sortField: sortField,
                sortAscending: sortAscending,
                buildsAlphaSections: buildsAlphaSections
            )
        }

        static func makeInputToken(source: LibrarySourceSnapshot, input: LibraryDerivedInput) -> LibraryDerivedInputToken {
            LibraryDerivedInputToken(sourceSignature: source.signature, input: input)
        }

        static func makeInputToken(
            books: [Book],
            searchText: String,
            selectedStatus: ReadingStatus?,
            selectedTag: String?,
            onlyWithNotes: Bool,
            sortField: SortField,
            sortAscending: Bool,
            buildsAlphaSections: Bool
        ) -> LibraryDerivedInputToken {
            let sourceSignature = LibrarySourceSnapshot.taskSignature(books: books)
            let input = makeInput(
                searchText: searchText,
                selectedStatus: selectedStatus,
                selectedTag: selectedTag,
                onlyWithNotes: onlyWithNotes,
                sortField: sortField,
                sortAscending: sortAscending,
                buildsAlphaSections: buildsAlphaSections
            )
            return LibraryDerivedInputToken(sourceSignature: sourceSignature, input: input)
        }

        static func makeDerivedState(
            source: LibrarySourceSnapshot,
            input: LibraryDerivedInput
        ) -> LibraryDerivedState {
            let filtered = filterBooks(source.books, input: input)
            let displayed = sortBooks(filtered, input: input)
            let alphaSections = input.buildsAlphaSections ? buildAlphaSections(from: displayed) : []

            return LibraryDerivedState(
                token: makeInputToken(source: source, input: input),
                displayedBookIDs: displayed.map(\.id),
                counts: statusCounts(in: source.books),
                alphaSections: alphaSections,
                alphaLetters: alphaSections.map(\.key)
            )
        }

        static func statusCounts(in books: [LibrarySourceSnapshot.BookSnapshot]) -> LibraryStatusCounts {
            var counts = LibraryStatusCounts.zero
            for book in books {
                switch book.status {
                case .toRead:
                    counts.toRead += 1
                case .reading:
                    counts.reading += 1
                case .finished:
                    counts.finished += 1
                }
            }
            return counts
        }

        static func filterBooks(
            _ books: [LibrarySourceSnapshot.BookSnapshot],
            input: LibraryDerivedInput
        ) -> [LibrarySourceSnapshot.BookSnapshot] {
            let hasSearch = !input.searchText.isEmpty

            return books.filter { book in
                if let selectedStatusRawValue = input.selectedStatusRawValue,
                   book.statusRawValue != selectedStatusRawValue {
                    return false
                }

                if let selectedTag = input.selectedTag,
                   !book.tags.contains(where: { $0.caseInsensitiveCompare(selectedTag) == .orderedSame }) {
                    return false
                }

                if input.onlyWithNotes, book.hasNotes == false {
                    return false
                }

                if hasSearch {
                    if book.title.localizedCaseInsensitiveContains(input.searchText) {
                        return true
                    }
                    if book.author.localizedCaseInsensitiveContains(input.searchText) {
                        return true
                    }
                    if book.isbn13?.localizedCaseInsensitiveContains(input.searchText) == true {
                        return true
                    }
                    if book.tags.contains(where: { $0.localizedCaseInsensitiveContains(input.searchText) }) {
                        return true
                    }
                    return false
                }

                return true
            }
        }

        static func sortBooks(
            _ books: [LibrarySourceSnapshot.BookSnapshot],
            input: LibraryDerivedInput
        ) -> [LibrarySourceSnapshot.BookSnapshot] {
            switch input.sortField {
            case .createdAt:
                return books.sorted { a, b in
                    if a.createdAt != b.createdAt {
                        return input.sortAscending ? (a.createdAt < b.createdAt) : (a.createdAt > b.createdAt)
                    }
                    return a.id.uuidString < b.id.uuidString
                }

            case .readDate:
                return books.sorted { a, b in
                    let aRead = readKeyDate(a)
                    let bRead = readKeyDate(b)

                    let aHas = aRead != nil
                    let bHas = bRead != nil

                    if aHas != bHas {
                        return aHas && !bHas
                    }

                    let da = aRead ?? a.createdAt
                    let db = bRead ?? b.createdAt

                    if da != db {
                        return input.sortAscending ? (da < db) : (da > db)
                    }
                    return a.id.uuidString < b.id.uuidString
                }

            case .rating:
                return books.sorted { a, b in
                    let ar = (a.status == .finished) ? a.userRatingAverage1 : nil
                    let br = (b.status == .finished) ? b.userRatingAverage1 : nil

                    let aHas = ar != nil
                    let bHas = br != nil

                    if aHas != bHas {
                        return aHas && !bHas
                    }

                    let ra = ar ?? -1
                    let rb = br ?? -1

                    if ra != rb {
                        return input.sortAscending ? (ra < rb) : (ra > rb)
                    }

                    let da = readKeyDate(a) ?? a.createdAt
                    let db = readKeyDate(b) ?? b.createdAt
                    if da != db {
                        return da > db
                    }
                    return a.id.uuidString < b.id.uuidString
                }

            case .title:
                return books.sorted { a, b in
                    let ta = bestTitle(a)
                    let tb = bestTitle(b)
                    let cmp = ta.localizedCaseInsensitiveCompare(tb)
                    if cmp != .orderedSame {
                        return input.sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                    }
                    return a.createdAt > b.createdAt
                }

            case .author:
                return books.sorted { a, b in
                    let aa = a.author.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ab = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sa = aa.isEmpty ? "—" : aa
                    let sb = ab.isEmpty ? "—" : ab
                    let cmp = sa.localizedCaseInsensitiveCompare(sb)
                    if cmp != .orderedSame {
                        return input.sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
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

        static func buildAlphaSections(
            from books: [LibrarySourceSnapshot.BookSnapshot]
        ) -> [AlphaSectionDescriptor] {
            var buckets: [String: [UUID]] = [:]

            for book in books {
                let key = alphaKey(for: bestTitle(book))
                buckets[key, default: []].append(book.id)
            }

            let keys = buckets.keys.sorted { a, b in
                if a == "#" { return false }
                if b == "#" { return true }
                return a < b
            }

            return keys.map { key in
                AlphaSectionDescriptor(id: key, key: key, bookIDs: buckets[key] ?? [])
            }
        }

        static func bestTitle(_ book: LibrarySourceSnapshot.BookSnapshot) -> String {
            let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Ohne Titel" : trimmed
        }

        static func readKeyDate(_ book: LibrarySourceSnapshot.BookSnapshot) -> Date? {
            guard book.status == .finished else { return nil }
            return book.readTo ?? book.readFrom
        }

        static func alphaKey(for title: String) -> String {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first = trimmed.first else { return "#" }

            let folded = String(first).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let upper = folded.uppercased()

            guard upper.unicodeScalars.count == 1,
                  let scalar = upper.unicodeScalars.first else {
                return "#"
            }

            let value = scalar.value
            if value >= 65 && value <= 90 {
                return upper
            }
            return "#"
        }
    }
}
