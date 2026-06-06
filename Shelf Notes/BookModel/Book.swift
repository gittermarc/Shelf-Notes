//
//  Book.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation
import SwiftData

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

    // ✅ Reading sessions (one-to-many)
    // CloudKit requires an inverse relationship.
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession]?

    // ✅ Reading attempts / Lesedurchgänge (one-to-many)
    // CloudKit requires an inverse relationship.
    @Relationship(deleteRule: .cascade, inverse: \ReadingAttempt.book)
    var readingAttempts: [ReadingAttempt]?

    // Imported metadata (bisher)
    var googleVolumeID: String?
    var isbn13: String?
    var thumbnailURL: String?

    /// Synced thumbnail cover (small JPEG).
    ///
    /// This is the single source of truth for cover rendering in the UI:
    /// - **User photo covers:** thumbnail is synced, full-res stays local on disk.
    /// - **Remote covers (Google/OpenLibrary):** thumbnail is generated on first load/import and then synced.
    ///
    /// Stored with external storage so SwiftData can keep the main store slim.
    @Attribute(.externalStorage)
    var userCoverData: Data?

    // User-selected cover (local file, optional)
    var userCoverFileName: String?
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

    // MARK: - User rating (1–5 each, 0 = nicht bewertet)

    var userRatingPlot: Int = 0                 // Handlung
    var userRatingCharacters: Int = 0           // Charaktere
    var userRatingWritingStyle: Int = 0         // Schreibstil
    var userRatingAtmosphere: Int = 0           // Atmosphäre/Stimmung
    var userRatingGenreFit: Int = 0             // Genre-Gerechtigkeit
    var userRatingPresentation: Int = 0         // Aufmachung (Cover/Layout)

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
        self.readingAttempts = nil
    }
}
