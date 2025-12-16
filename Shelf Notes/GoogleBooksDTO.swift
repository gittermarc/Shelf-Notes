//
//  GoogleBooksDTO.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation

struct GoogleBooksVolumesResponse: Decodable {
    let totalItems: Int?
    let items: [GoogleBookVolume]?
}

struct GoogleBookVolume: Decodable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo
}

struct VolumeInfo: Decodable {
    let title: String?
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let description: String?
    let pageCount: Int?
    let categories: [String]?
    let language: String?
    let industryIdentifiers: [IndustryIdentifier]?
    let imageLinks: ImageLinks?
}

struct IndustryIdentifier: Decodable {
    let type: String?
    let identifier: String?
}

struct ImageLinks: Decodable {
    let smallThumbnail: String?
    let thumbnail: String?
}

extension GoogleBookVolume {
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

    var bestThumbnailURLString: String? {
        // Prefer thumbnail over smallThumbnail
        let raw = volumeInfo.imageLinks?.thumbnail ?? volumeInfo.imageLinks?.smallThumbnail
        return toHTTPS(raw)
    }
}
