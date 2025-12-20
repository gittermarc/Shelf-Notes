//
//  Book.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation
import SwiftData

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case toRead = "Will ich lesen"
    case reading = "Lese ich gerade"
    case finished = "Gelesen"

    var id: String { rawValue }
}

@Model
final class Book {
    // CloudKit/SwiftData: KEIN @Attribute(.unique)
    var id: UUID = UUID()

    // Core
    var title: String = ""
    var author: String = ""
    var createdAt: Date = Date()
    var statusRawValue: String = ReadingStatus.toRead.rawValue
    var tags: [String] = []
    var notes: String = ""

    // Reading period (für Zeitleiste / Goals)
    var readFrom: Date?
    var readTo: Date?

    // ✅ Collections / Listen (many-to-many)
    // CloudKit: Beziehungen müssen optional sein
    // -> kein @Relationship-Macro nötig (und bei dir zuletzt problematisch)
    var collections: [BookCollection]?

    // Imported metadata (bisher)
    var googleVolumeID: String?
    var isbn13: String?
    var thumbnailURL: String?
    var publisher: String?
    var publishedDate: String?
    var pageCount: Int?
    var language: String?
    var categories: [String] = []
    var bookDescription: String = ""

    // ✅ Neue Metadaten (persistiert)
    // VolumeInfo
    var subtitle: String?
    var previewLink: String?
    var infoLink: String?
    var canonicalVolumeLink: String?

    var averageRating: Double?
    var ratingsCount: Int?

    var mainCategory: String?

    /// Mehr Cover-Varianten (best-first), falls vorhanden
    var coverURLCandidates: [String] = []

    // AccessInfo
    var viewability: String?
    var isPublicDomain: Bool = false
    var isEmbeddable: Bool = false

    var isEpubAvailable: Bool = false
    var isPdfAvailable: Bool = false
    var epubAcsTokenLink: String?
    var pdfAcsTokenLink: String?

    // SaleInfo
    var saleability: String?
    var isEbook: Bool = false

    var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusRawValue) ?? .toRead }
        set { statusRawValue = newValue.rawValue }
    }

    // MARK: - Cover helpers (Google → persisted candidates → OpenLibrary fallback)

    private func toHTTPS(_ urlString: String?) -> String? {
        guard var s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }

        if s.hasPrefix("http://") {
            s = "https://" + s.dropFirst("http://".count)
        } else if s.hasPrefix("http:") {
            s = "https:" + s.dropFirst("http:".count)
        }
        return s
    }

    /// Best cover URL for UI:
    /// - 1) thumbnailURL (if present)
    /// - 2) persisted coverURLCandidates
    /// - 3) OpenLibrary fallback (if ISBN available)
    var bestCoverURLString: String? {
        if let primary = toHTTPS(thumbnailURL) { return primary }

        for c in coverURLCandidates {
            if let https = toHTTPS(c) { return https }
        }

        return openLibraryCoverURLCandidates.first
    }

    // Komfort: nil wie leeres Array behandeln
    var collectionsSafe: [BookCollection] {
        get { collections ?? [] }
        set { collections = newValue }
    }

    init(
        title: String,
        author: String = "",
        status: ReadingStatus = .toRead,
        tags: [String] = [],
        notes: String = ""
    ) {
        self.title = title
        self.author = author
        self.statusRawValue = status.rawValue
        self.tags = tags
        self.notes = notes
        self.collections = nil
    }
}

// MARK: - Collections helpers

extension Book {
    func isInCollection(_ collection: BookCollection) -> Bool {
        collectionsSafe.contains(where: { $0.id == collection.id })
    }

    func addToCollection(_ collection: BookCollection) {
        if isInCollection(collection) { return }
        var arr = collectionsSafe
        arr.append(collection)
        collectionsSafe = arr
    }

    func removeFromCollection(_ collection: BookCollection) {
        var arr = collectionsSafe
        arr.removeAll { $0.id == collection.id }
        collectionsSafe = arr
    }
}

// MARK: - Cover helpers (Google + OpenLibrary + persistence)

extension Book {
    /// OpenLibrary fallback (best-first). Uses `default=false` so we can detect missing covers via 404.
    var openLibraryCoverURLCandidates: [String] {
        guard let raw = isbn13?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return [] }
        let isbn = raw.filter(\.isNumber)
        guard !isbn.isEmpty else { return [] }

        return [
            "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false",
            "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg?default=false",
            "https://covers.openlibrary.org/b/isbn/\(isbn)-S.jpg?default=false"
        ]
    }

    /// Best-first list of cover candidates for display.
    /// - includes persisted `thumbnailURL` first
    /// - then any stored `coverURLCandidates`
    /// - then OpenLibrary fallback by ISBN
    var coverCandidatesAll: [String] {
        var out: [String] = []

        func add(_ s: String?) {
            guard let s else { return }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        add(thumbnailURL)
        for s in coverURLCandidates { add(s) }
        for s in openLibraryCoverURLCandidates { add(s) }

        return out
    }

    /// Persists the winning cover URL for later ("instant" next time) and moves it to the front of candidates.
    func persistResolvedCoverURL(_ urlString: String) {
        let t = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        // Persist as primary
        if thumbnailURL?.caseInsensitiveCompare(t) != .orderedSame {
            thumbnailURL = t
        }

        // Keep candidates list deduped + best-first
        var arr = coverURLCandidates
        arr.removeAll { $0.caseInsensitiveCompare(t) == .orderedSame }
        arr.insert(t, at: 0)
        coverURLCandidates = arr
    }
}
