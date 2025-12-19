//
//  GoogleBooksDTO.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation

// MARK: - Root Response

struct GoogleBooksVolumesResponse: Decodable {
    let totalItems: Int?
    let items: [GoogleBookVolume]?
}

// MARK: - Volume Item

struct GoogleBookVolume: Decodable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo

    // Additional rich metadata you want:
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

    // Ratings
    let averageRating: Double?
    let ratingsCount: Int?

    // Links
    let previewLink: String?
    let infoLink: String?
    let canonicalVolumeLink: String?

    // IDs & Covers
    let industryIdentifiers: [IndustryIdentifier]?
    let imageLinks: ImageLinks?
}

struct IndustryIdentifier: Decodable {
    let type: String?
    let identifier: String?
}

// MARK: - ImageLinks (more variants)

struct ImageLinks: Decodable {
    let smallThumbnail: String?
    let thumbnail: String?

    // Often present depending on record quality:
    let small: String?
    let medium: String?
    let large: String?
    let extraLarge: String?
}

// MARK: - AccessInfo (viewability / embeddable / epub/pdf)

struct AccessInfo: Decodable {
    let country: String?
    let viewability: String?     // e.g. "PARTIAL", "ALL_PAGES", "NO_PAGES"
    let embeddable: Bool?
    let publicDomain: Bool?

    let epub: BookFormatAvailability?
    let pdf: BookFormatAvailability?
}

struct BookFormatAvailability: Decodable {
    let isAvailable: Bool?
    let acsTokenLink: String?    // sometimes present for downloads/preview flows
}

// MARK: - SaleInfo (saleability)

struct SaleInfo: Decodable {
    let country: String?
    let saleability: String?     // e.g. "FOR_SALE", "NOT_FOR_SALE", "FREE"
    let isEbook: Bool?
}

// MARK: - Convenience accessors

extension GoogleBookVolume {
    // Existing (kept for compatibility)
    var bestTitle: String { volumeInfo.title ?? "Ohne Titel" }

    var bestAuthors: String {
        let a = volumeInfo.authors ?? []
        return a.isEmpty ? "" : a.joined(separator: ", ")
    }

    var isbn13: String? {
        let ids = volumeInfo.industryIdentifiers ?? []
        if let isbn13 = ids.first(where: { $0.type == "ISBN_13" })?.identifier {
            return isbn13
        }
        return nil
    }

    // New: subtitle
    var bestSubtitle: String? {
        let s = volumeInfo.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    // New: links
    var previewLink: String? { toHTTPS(volumeInfo.previewLink) }
    var infoLink: String? { toHTTPS(volumeInfo.infoLink) }
    var canonicalVolumeLink: String? { toHTTPS(volumeInfo.canonicalVolumeLink) }

    // New: ratings
    var averageRating: Double? { volumeInfo.averageRating }
    var ratingsCount: Int? { volumeInfo.ratingsCount }

    // New: categories / genre-like
    var allCategories: [String] {
        var set = Set<String>()
        if let main = volumeInfo.mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
           !main.isEmpty { set.insert(main) }

        for c in (volumeInfo.categories ?? []) {
            let v = c.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { set.insert(v) }
        }
        return Array(set).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // New: access/viewability flags
    var viewability: String? { accessInfo?.viewability }
    var isPublicDomain: Bool { accessInfo?.publicDomain ?? false }
    var isEmbeddable: Bool { accessInfo?.embeddable ?? false }

    // New: EPUB/PDF availability
    var isEpubAvailable: Bool { accessInfo?.epub?.isAvailable ?? false }
    var isPdfAvailable: Bool { accessInfo?.pdf?.isAvailable ?? false }
    var epubAcsTokenLink: String? { toHTTPS(accessInfo?.epub?.acsTokenLink) }
    var pdfAcsTokenLink: String? { toHTTPS(accessInfo?.pdf?.acsTokenLink) }

    // New: saleability
    var saleability: String? { saleInfo?.saleability }
    var isEbook: Bool { saleInfo?.isEbook ?? false }

    // Helper (kept, but now reused for more fields)
    fileprivate func toHTTPS(_ urlString: String?) -> String? {
        guard var s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }

        if s.hasPrefix("http://") {
            s = "https://" + s.dropFirst("http://".count)
        } else if s.hasPrefix("http:") {
            s = "https:" + s.dropFirst("http:".count)
        }

        return s
    }

    /// Existing behavior preserved: best "thumbnail" or "smallThumbnail"
    var bestThumbnailURLString: String? {
        let raw = volumeInfo.imageLinks?.thumbnail ?? volumeInfo.imageLinks?.smallThumbnail
        return toHTTPS(raw)
    }

    /// New: more cover variants — returns ALL candidates, best-first
    var coverURLCandidates: [String] {
        guard let links = volumeInfo.imageLinks else { return [] }

        let rawCandidates: [String?] = [
            links.extraLarge,
            links.large,
            links.medium,
            links.small,
            links.thumbnail,
            links.smallThumbnail
        ]

        // normalize + dedupe while keeping order
        var seen = Set<String>()
        var out: [String] = []

        for raw in rawCandidates {
            guard let https = toHTTPS(raw) else { continue }
            if seen.contains(https) { continue }
            seen.insert(https)
            out.append(https)
        }

        return out
    }

    /// New: "best" cover URL using the expanded candidate list
    var bestCoverURLString: String? {
        coverURLCandidates.first
    }
}
