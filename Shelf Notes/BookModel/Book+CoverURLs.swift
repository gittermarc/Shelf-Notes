//
//  Book+CoverURLs.swift
//  Shelf Notes
//

import Foundation

extension Book {
    /// Best cover URL for UI:
    /// - 0) local user-selected cover file when synced thumbnail is unavailable
    /// - 1) thumbnailURL (if present)
    /// - 2) persisted coverURLCandidates
    /// - 3) OpenLibrary fallback (if ISBN available)
    var bestCoverURLString: String? {
        if userCoverData == nil,
           let name = userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: name) {
            return fileURL.absoluteString
        }

        if let primary = normalizedHTTPSURLString(from: thumbnailURL) {
            return primary
        }

        for candidate in coverURLCandidates {
            if let normalized = normalizedHTTPSURLString(from: candidate) {
                return normalized
            }
        }

        return openLibraryCoverURLCandidates.first
    }

    /// OpenLibrary fallback (best-first). Uses `default=false` so we can detect missing covers via 404.
    var openLibraryCoverURLCandidates: [String] {
        guard let raw = isbn13?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return []
        }

        let isbn = raw.filter(\.isNumber)
        guard !isbn.isEmpty else { return [] }

        return [
            "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false",
            "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg?default=false",
            "https://covers.openlibrary.org/b/isbn/\(isbn)-S.jpg?default=false"
        ]
    }

    /// Best-first list of cover candidates for display.
    /// - includes local file cover first
    /// - then persisted `thumbnailURL`
    /// - then any stored `coverURLCandidates`
    /// - then OpenLibrary fallback by ISBN
    var coverCandidatesAll: [String] {
        var out: [String] = []

        func add(_ value: String?) {
            guard let value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                out.append(trimmed)
            }
        }

        if let name = userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: name) {
            add(fileURL.absoluteString)
        }

        add(normalizedHTTPSURLString(from: thumbnailURL))
        for candidate in coverURLCandidates {
            add(normalizedHTTPSURLString(from: candidate))
        }
        for candidate in openLibraryCoverURLCandidates {
            add(candidate)
        }

        return out
    }

    /// Persists the winning cover URL for later and moves it to the front of candidates.
    func persistResolvedCoverURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = URL(string: trimmed), url.isFileURL {
            return
        }

        let normalized = normalizedHTTPSURLString(from: trimmed) ?? trimmed

        if thumbnailURL?.caseInsensitiveCompare(normalized) != .orderedSame {
            thumbnailURL = normalized
        }

        var candidates = coverURLCandidates
        candidates.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        candidates.insert(normalized, at: 0)
        coverURLCandidates = candidates
    }

    fileprivate func normalizedHTTPSURLString(from urlString: String?) -> String? {
        guard var value = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if value.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        } else if value.hasPrefix("http:") {
            value = "https:" + value.dropFirst("http:".count)
        }

        return value
    }
}
