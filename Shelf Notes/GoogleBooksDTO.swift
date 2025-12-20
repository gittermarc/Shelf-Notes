//
//  GoogleBooksDTO.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation

// MARK: - Top-level response

struct GoogleBooksVolumesResponse: Decodable {
    let totalItems: Int?
    let items: [GoogleBookVolume]?
}

// MARK: - Volume

struct GoogleBookVolume: Decodable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo
    let accessInfo: AccessInfo?
    let saleInfo: SaleInfo?
}

// MARK: - VolumeInfo

struct VolumeInfo: Decodable {
    let title: String?
    let subtitle: String?

    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let description: String?

    let pageCount: Int?
    let categories: [String]?
    let mainCategory: String?
    let language: String?

    let industryIdentifiers: [IndustryIdentifier]?
    let imageLinks: ImageLinks?

    let previewLink: String?
    let infoLink: String?
    let canonicalVolumeLink: String?

    let averageRating: Double?
    let ratingsCount: Int?
}

struct IndustryIdentifier: Decodable {
    let type: String?
    let identifier: String?
}

struct ImageLinks: Decodable {
    let smallThumbnail: String?
    let thumbnail: String?

    // Not always present, but supported by the API for many volumes
    let small: String?
    let medium: String?
    let large: String?
    let extraLarge: String?
}

// MARK: - AccessInfo

struct AccessInfo: Decodable {
    let viewability: String?
    let publicDomain: Bool?
    let embeddable: Bool?

    let epub: DigitalFormat?
    let pdf: DigitalFormat?
}

struct DigitalFormat: Decodable {
    let isAvailable: Bool?
    let acsTokenLink: String?
}

// MARK: - SaleInfo

struct SaleInfo: Decodable {
    let saleability: String?
    let isEbook: Bool?
}

// MARK: - Helpers / computed mapping

extension GoogleBookVolume {
    var bestTitle: String { (volumeInfo.title ?? "Ohne Titel").trimmingCharacters(in: .whitespacesAndNewlines) }

    var bestSubtitle: String? {
        let s = (volumeInfo.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    var bestAuthors: String {
        let a = (volumeInfo.authors ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return a.isEmpty ? "" : a.joined(separator: ", ")
    }

    var isbn13: String? {
        let ids = volumeInfo.industryIdentifiers ?? []
        if let raw = ids.first(where: { $0.type == "ISBN_13" })?.identifier {
            let cleaned = raw.filter(\.isNumber)
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }

    var allCategories: [String] {
        var out: [String] = []
        func add(_ s: String?) {
            guard let s else { return }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        add(volumeInfo.mainCategory)
        for c in (volumeInfo.categories ?? []) { add(c) }
        return out
    }

    // MARK: Links

    var previewLink: String? { toHTTPS(volumeInfo.previewLink) }
    var infoLink: String? { toHTTPS(volumeInfo.infoLink) }
    var canonicalVolumeLink: String? { toHTTPS(volumeInfo.canonicalVolumeLink) }

    // MARK: Ratings

    var averageRating: Double? { volumeInfo.averageRating }
    var ratingsCount: Int? { volumeInfo.ratingsCount }

    // MARK: Access

    var viewability: String? { accessInfo?.viewability }
    var isPublicDomain: Bool { accessInfo?.publicDomain ?? false }
    var isEmbeddable: Bool { accessInfo?.embeddable ?? false }

    var isEpubAvailable: Bool { accessInfo?.epub?.isAvailable ?? false }
    var isPdfAvailable: Bool { accessInfo?.pdf?.isAvailable ?? false }

    var epubAcsTokenLink: String? { toHTTPS(accessInfo?.epub?.acsTokenLink) }
    var pdfAcsTokenLink: String? { toHTTPS(accessInfo?.pdf?.acsTokenLink) }

    // MARK: Sale

    var saleability: String? { saleInfo?.saleability }
    var isEbook: Bool { saleInfo?.isEbook ?? false }

    // MARK: Cover candidates

    /// OpenLibrary fallback (best-first). Uses `default=false` so we can detect missing covers via 404.
    var openLibraryCoverURLCandidates: [String] {
        guard let isbn = isbn13 else { return [] }
        return [
            "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false",
            "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg?default=false",
            "https://covers.openlibrary.org/b/isbn/\(isbn)-S.jpg?default=false"
        ]
    }

    /// Best-first candidates. Not all fields exist for every volume.
    var coverURLCandidates: [String] {
        var out: [String] = []

        func add(_ raw: String?) {
            guard let s = toHTTPS(raw) else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(s) == .orderedSame }) {
                out.append(s)
            }
        }

        // Prefer larger if present
        add(volumeInfo.imageLinks?.extraLarge)
        add(volumeInfo.imageLinks?.large)
        add(volumeInfo.imageLinks?.medium)
        add(volumeInfo.imageLinks?.small)

        // Classic fields
        add(volumeInfo.imageLinks?.thumbnail)
        add(volumeInfo.imageLinks?.smallThumbnail)

        // OpenLibrary fallback at the end
        for s in openLibraryCoverURLCandidates { add(s) }

        return out
    }

    var bestCoverURLString: String? { coverURLCandidates.first }

    /// Kept for older call sites (if you only want the classic thumbnail field).
    var bestThumbnailURLString: String? {
        // Prefer thumbnail over smallThumbnail
        let raw = volumeInfo.imageLinks?.thumbnail ?? volumeInfo.imageLinks?.smallThumbnail
        return toHTTPS(raw)
    }

    // MARK: - Internal helpers

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
}
