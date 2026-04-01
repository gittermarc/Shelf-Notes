//
//  Book+Importing.swift
//  Shelf Notes
//
//  Helpers to map GoogleBooks volumes to Book model instances.
//

import Foundation

extension GoogleBookVolume {
    /// Creates a fully-mapped `Book` instance from a Google Books volume.
    ///
    /// This mirrors the mapping used in the manual "Buch hinzufügen" flow.
    func toBook(status: ReadingStatus = .toRead) -> Book {
        let info = volumeInfo

        let bestCover = (bestCoverURLString ?? bestThumbnailURLString)

        let b = Book(
            title: bestTitle,
            author: bestAuthors,
            status: status
        )

        // Imported metadata
        b.googleVolumeID = id
        b.isbn13 = isbn13
        b.thumbnailURL = bestCover

        b.publisher = info.publisher
        b.publishedDate = info.publishedDate
        b.pageCount = info.pageCount
        b.language = info.language
        b.categories = allCategories
        b.bookDescription = info.description ?? ""

        // Rich metadata
        b.subtitle = bestSubtitle
        b.previewLink = previewLink
        b.infoLink = infoLink
        b.canonicalVolumeLink = canonicalVolumeLink

        b.averageRating = averageRating
        b.ratingsCount = ratingsCount
        b.mainCategory = info.mainCategory

        b.coverURLCandidates = coverURLCandidates

        // Access info
        b.viewability = viewability
        b.isPublicDomain = isPublicDomain
        b.isEmbeddable = isEmbeddable

        b.isEpubAvailable = isEpubAvailable
        b.isPdfAvailable = isPdfAvailable
        b.epubAcsTokenLink = epubAcsTokenLink
        b.pdfAcsTokenLink = pdfAcsTokenLink

        // Sale info
        b.saleability = saleability
        b.isEbook = isEbook

        return b
    }
}
