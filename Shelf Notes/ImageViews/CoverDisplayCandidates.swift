//
//  CoverDisplayCandidates.swift
//  Shelf Notes
//

import Foundation

enum CoverDisplayCandidates {
    /// Creates a best-effort list of display candidates:
    /// - For remote URLs we add a zoom-upgraded variant (Google Books) before the original.
    /// - File URLs are kept as-is.
    /// - Duplicates are removed while preserving order.
    static func make(from raw: [String]) -> [String] {
        var output: [String] = []

        func add(_ string: String) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !output.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                output.append(trimmed)
            }
        }

        for candidate in raw {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let url = URL(string: trimmed), url.isFileURL {
                add(trimmed)
                continue
            }

            let upgraded = CoverThumbnailer.upgradedRemoteURLString(trimmed, target: .display)
            if upgraded.caseInsensitiveCompare(trimmed) == .orderedSame {
                add(trimmed)
            } else {
                add(upgraded)
                add(trimmed)
            }
        }

        return output
    }

    /// Picks a preferred starting URL for high-resolution rendering.
    /// - User photo cover (local file) wins.
    /// - Otherwise we prefer the upgraded display variant of the persisted primary URL.
    static func preferredHighResURLString(
        userCoverFileName: String?,
        thumbnailURL: String?,
        coverURLCandidates: [String]
    ) -> String? {
        if let name = userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: name) {
            return fileURL.absoluteString
        }

        if let thumbnail = thumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines), !thumbnail.isEmpty {
            return CoverThumbnailer.upgradedRemoteURLString(thumbnail, target: .display)
        }

        if let firstCandidate = coverURLCandidates.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstCandidate.isEmpty {
            return CoverThumbnailer.upgradedRemoteURLString(firstCandidate, target: .display)
        }

        return nil
    }

    static func preferredHighResURLString(for book: Book) -> String? {
        preferredHighResURLString(
            userCoverFileName: book.userCoverFileName,
            thumbnailURL: book.thumbnailURL,
            coverURLCandidates: book.coverURLCandidates
        )
    }
}
