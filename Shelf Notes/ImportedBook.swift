//
/*  ImportedBook.swift
    Shelf Notes

    Extracted from BookImportView.swift to keep the import flow maintainable.
*/

import Foundation

struct ImportedBook {
    let googleVolumeID: String
    let title: String
    let author: String
    let isbn13: String?

    /// Primary cover used across the app
    let thumbnailURL: String?

    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
    let language: String?
    let categories: [String]
    let description: String

    // ✅ Rich metadata
    let subtitle: String?
    let previewLink: String?
    let infoLink: String?
    let canonicalVolumeLink: String?

    let averageRating: Double?
    let ratingsCount: Int?
    let mainCategory: String?

    let coverURLCandidates: [String]

    let viewability: String?
    let isPublicDomain: Bool
    let isEmbeddable: Bool

    let isEpubAvailable: Bool
    let isPdfAvailable: Bool
    let epubAcsTokenLink: String?
    let pdfAcsTokenLink: String?

    let saleability: String?
    let isEbook: Bool
}

extension ImportedBook {
    init(volume: GoogleBookVolume) {
        let info = volume.volumeInfo
        let bestCover = (volume.bestCoverURLString ?? volume.bestThumbnailURLString)

        self.init(
            googleVolumeID: volume.id,
            title: volume.bestTitle,
            author: volume.bestAuthors,
            isbn13: volume.isbn13,
            thumbnailURL: bestCover,
            publisher: info.publisher,
            publishedDate: info.publishedDate,
            pageCount: info.pageCount,
            language: info.language,
            categories: volume.allCategories,
            description: info.description ?? "",
            subtitle: volume.bestSubtitle,
            previewLink: volume.previewLink,
            infoLink: volume.infoLink,
            canonicalVolumeLink: volume.canonicalVolumeLink,
            averageRating: volume.averageRating,
            ratingsCount: volume.ratingsCount,
            mainCategory: info.mainCategory,
            coverURLCandidates: volume.coverURLCandidates,
            viewability: volume.viewability,
            isPublicDomain: volume.isPublicDomain,
            isEmbeddable: volume.isEmbeddable,
            isEpubAvailable: volume.isEpubAvailable,
            isPdfAvailable: volume.isPdfAvailable,
            epubAcsTokenLink: volume.epubAcsTokenLink,
            pdfAcsTokenLink: volume.pdfAcsTokenLink,
            saleability: volume.saleability,
            isEbook: volume.isEbook
        )
    }
}
