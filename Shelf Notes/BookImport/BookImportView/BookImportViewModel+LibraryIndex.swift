//
//  BookImportViewModel+LibraryIndex.swift
//  Shelf Notes
//
//  Dedupe/indexing against the existing library and session additions.
//

import Foundation

@MainActor
extension BookImportViewModel {

    func updateExistingBooks(_ books: [Book]) {
        // index: volumeIDs
        libraryVolumeIDs = Set(books.compactMap { b in
            let id = (b.googleVolumeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        })

        // index: ISBNs
        libraryISBNsLowercased = Set(books.compactMap { b in
            let isbn = (b.isbn13 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return isbn.isEmpty ? nil : isbn.lowercased()
        })

        if hideAlreadyInLibrary {
            applyLocalFilters()
        }
    }

    func isAlreadyAdded(_ volume: GoogleBookVolume) -> Bool {
        if addedVolumeIDs.contains(volume.id) { return true }
        if libraryVolumeIDs.contains(volume.id) { return true }

        if let isbn = volume.isbn13?.trimmingCharacters(in: .whitespacesAndNewlines),
           !isbn.isEmpty,
           libraryISBNsLowercased.contains(isbn.lowercased()) {
            return true
        }

        return false
    }

}
