//
//  GoogleVolumeBookMapper.swift
//  Shelf Notes
//
//  Maps GoogleBooks DTOs to our SwiftData Book model.
//  Extracted from BookImportViewModel to reduce responsibilities.
//

import Foundation

struct GoogleVolumeBookMapper {
    func makeBook(from volume: GoogleBookVolume, status: ReadingStatus) -> Book {
        let info = volume.volumeInfo

        let newBook = Book(
            title: volume.bestTitle,
            author: volume.bestAuthors,
            status: status
        )

        if status == .finished {
            newBook.readFrom = Date()
            newBook.readTo = Date()
        } else {
            newBook.readFrom = nil
            newBook.readTo = nil
        }

        newBook.googleVolumeID = volume.id
        newBook.isbn13 = volume.isbn13

        let bestCover = (volume.bestCoverURLString ?? volume.bestThumbnailURLString)
        newBook.thumbnailURL = bestCover

        newBook.publisher = info.publisher
        newBook.publishedDate = info.publishedDate
        newBook.pageCount = info.pageCount
        newBook.language = info.language

        newBook.categories = volume.allCategories
        newBook.bookDescription = info.description ?? ""

        // ✅ Rich metadata mappings
        newBook.subtitle = volume.bestSubtitle
        newBook.previewLink = volume.previewLink
        newBook.infoLink = volume.infoLink
        newBook.canonicalVolumeLink = volume.canonicalVolumeLink

        newBook.averageRating = volume.averageRating
        newBook.ratingsCount = volume.ratingsCount
        newBook.mainCategory = info.mainCategory

        newBook.coverURLCandidates = volume.coverURLCandidates

        newBook.viewability = volume.viewability
        newBook.isPublicDomain = volume.isPublicDomain
        newBook.isEmbeddable = volume.isEmbeddable

        newBook.isEpubAvailable = volume.isEpubAvailable
        newBook.isPdfAvailable = volume.isPdfAvailable
        newBook.epubAcsTokenLink = volume.epubAcsTokenLink
        newBook.pdfAcsTokenLink = volume.pdfAcsTokenLink

        newBook.saleability = volume.saleability
        newBook.isEbook = volume.isEbook

        return newBook
    }
}
