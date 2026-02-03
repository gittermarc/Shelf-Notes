//
//  BookImportFilterEngine.swift
//  Shelf Notes
//
//  Pure-ish filtering/sorting for Google Books search results.
//  Extracted from BookImportViewModel to improve testability and reduce file size.
//

import Foundation

/// Applies *local* (device-side) filtering/sorting to already fetched Google Books volumes.
///
/// Important design choice:
/// - **Server-side filters** (language, Google filter, category/subject) are applied *only* via the API request.
/// - This engine intentionally **does not re-apply those filters locally**, because local best-effort matching
///   can disagree with Google's matching and accidentally hide valid results ("0 Treffer" despite Google hits).
struct BookImportFilterEngine {
    struct Input {
        let volumes: [GoogleBookVolume]

        /// Only used to keep the category picker stable (include the selected value even if it doesn't occur in the fetched set).
        let selectedCategory: String

        // Local "quality" filters
        let onlyWithCover: Bool
        let onlyWithISBN: Bool
        let onlyWithDescription: Bool
        let hideAlreadyInLibrary: Bool
        let collapseDuplicates: Bool

        let sortOption: BookImportSortOption
    }

    struct Output {
        let results: [GoogleBookVolume]
        let availableCategories: [String]
    }

    func apply(
        input: Input,
        isAlreadyAdded: (GoogleBookVolume) -> Bool
    ) -> Output {
        // Keep category list in sync with the fetched set.
        let categories = Self.computeAvailableCategories(from: input.volumes, includeSelected: input.selectedCategory)

        var filtered = input.volumes

        // Local quality filters
        if input.onlyWithCover {
            filtered = filtered.filter { vol in
                let cover = vol.bestCoverURLString ?? vol.bestThumbnailURLString
                return (cover?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            }
        }

        if input.onlyWithISBN {
            filtered = filtered.filter { vol in
                let isbn = vol.isbn13?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !isbn.isEmpty
            }
        }

        if input.onlyWithDescription {
            filtered = filtered.filter { vol in
                let d = (vol.volumeInfo.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return !d.isEmpty
            }
        }

        if input.hideAlreadyInLibrary {
            filtered = filtered.filter { !isAlreadyAdded($0) }
        }

        if input.collapseDuplicates {
            filtered = collapseNearDuplicates(filtered)
        }

        filtered = sortVolumes(filtered, sortOption: input.sortOption)

        return Output(results: filtered, availableCategories: categories)
    }

    // MARK: - Categories

    static func computeAvailableCategories(from volumes: [GoogleBookVolume], includeSelected selected: String) -> [String] {
        BookImportCategoryNormalizer.computeAvailableCategoryDisplays(from: volumes.map { $0.allCategories }, includeSelected: selected)
    }

    // MARK: - Dedupe

    private func collapseNearDuplicates(_ input: [GoogleBookVolume]) -> [GoogleBookVolume] {
        var seen: Set<String> = []
        var out: [GoogleBookVolume] = []
        out.reserveCapacity(input.count)

        for v in input {
            let key: String
            if let isbn = v.isbn13?.trimmingCharacters(in: .whitespacesAndNewlines), !isbn.isEmpty {
                key = "isbn|\(isbn.lowercased())"
            } else {
                let t = v.bestTitle.lowercased()
                let a = v.bestAuthors.lowercased()
                key = "ta|\(t)|\(a)"
            }

            if seen.insert(key).inserted {
                out.append(v)
            }
        }

        return out
    }

    // MARK: - Sorting

    private func sortVolumes(_ input: [GoogleBookVolume], sortOption: BookImportSortOption) -> [GoogleBookVolume] {
        switch sortOption {
        case .relevance:
            return input
        case .newest:
            return input.sorted { a, b in
                let ya = publishedYear(a)
                let yb = publishedYear(b)
                if ya != yb { return (ya ?? Int.min) > (yb ?? Int.min) }
                return a.bestTitle.localizedCaseInsensitiveCompare(b.bestTitle) == .orderedAscending
            }
        case .titleAZ:
            return input.sorted { a, b in
                a.bestTitle.localizedCaseInsensitiveCompare(b.bestTitle) == .orderedAscending
            }
        case .quality:
            return input.sorted { a, b in
                let sa = qualityScore(a)
                let sb = qualityScore(b)
                if sa != sb { return sa > sb }
                let ya = publishedYear(a)
                let yb = publishedYear(b)
                if ya != yb { return (ya ?? Int.min) > (yb ?? Int.min) }
                return a.bestTitle.localizedCaseInsensitiveCompare(b.bestTitle) == .orderedAscending
            }
        }
    }

    private func publishedYear(_ volume: GoogleBookVolume) -> Int? {
        let raw = (volume.volumeInfo.publishedDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count >= 4 else { return nil }
        let prefix = String(raw.prefix(4))
        return Int(prefix)
    }

    private func qualityScore(_ volume: GoogleBookVolume) -> Int {
        var score = 0

        if let c = (volume.bestCoverURLString ?? volume.bestThumbnailURLString), !c.isEmpty { score += 6 }
        if let isbn = volume.isbn13, !isbn.isEmpty { score += 6 }
        if (volume.volumeInfo.pageCount ?? 0) > 0 { score += 2 }
        if !(volume.bestAuthors.isEmpty) { score += 2 }
        if let d = volume.volumeInfo.description, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 2 }
        if let _ = publishedYear(volume) { score += 1 }

        // A tiny bump if there are ratings (many volumes don't have them).
        if let rc = volume.ratingsCount, rc > 0 { score += 1 }

        return score
    }
}
