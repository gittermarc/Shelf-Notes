//
//  Book.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation
import SwiftData

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    /// Stable persisted codes (do not localize).
    case toRead = "toRead"
    case reading = "reading"
    case finished = "finished"

    var id: String { rawValue }

    /// User-facing label (safe to change / localize).
    var displayName: String {
        switch self {
        case .toRead: return "Will ich lesen"
        case .reading: return "Lese ich gerade"
        case .finished: return "Gelesen"
        }
    }

    /// Maps both stable codes and legacy persisted display strings to a status.
    static func fromPersisted(_ value: String) -> ReadingStatus? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // v2+ stable codes
        if let s = ReadingStatus(rawValue: trimmed) { return s }

        // v1 legacy persisted values (display strings)
        switch trimmed {
        case "Will ich lesen", "Will lesen":
            return .toRead
        case "Lese ich gerade", "Lese ich":
            return .reading
        case "Gelesen":
            return .finished
        default:
            return nil
        }
    }
}

/// One-time migration:
/// - v1 persisted `ReadingStatus` as localized display strings (e.g. "Gelesen").
/// - v2 persists stable codes ("toRead"/"reading"/"finished") and renders UI via `displayName`.
///
/// This migrator rewrites legacy `Book.statusRawValue` values to the stable codes.
enum ReadingStatusMigrator {

    private static let migrationKey = "did_migrate_reading_status_codes_v1"

    @MainActor
    static func migrateIfNeeded(modelContext: ModelContext) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: migrationKey) == false else { return }

        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> {
                $0.statusRawValue == "Will ich lesen" ||
                $0.statusRawValue == "Lese ich gerade" ||
                $0.statusRawValue == "Gelesen" ||
                $0.statusRawValue == "Will lesen" ||
                $0.statusRawValue == "Lese ich"
            }
        )

        do {
            let books = try modelContext.fetch(descriptor)
            guard !books.isEmpty else {
                defaults.set(true, forKey: migrationKey)
                return
            }

            var didChange = false
            for b in books {
                guard let mapped = ReadingStatus.fromPersisted(b.statusRawValue) else { continue }

                // Store the stable code (rawValue) instead of a localized label.
                if b.statusRawValue != mapped.rawValue {
                    b.statusRawValue = mapped.rawValue
                    didChange = true
                }
            }

            if didChange {
                _ = modelContext.saveWithDiagnostics()
            }

            defaults.set(true, forKey: migrationKey)
        } catch {
            // If this fails, we will retry next launch.
            #if DEBUG
            print("ReadingStatusMigrator failed: \(error)")
            #endif
        }
    }
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

    // ✅ Reading sessions (one-to-many)
    // CloudKit requires an inverse relationship.
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession]?

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

    /// All rating fields in one place (0 = not rated)
    var userRatingValues: [Int] {
        [
            userRatingPlot,
            userRatingCharacters,
            userRatingWritingStyle,
            userRatingAtmosphere,
            userRatingGenreFit,
            userRatingPresentation
        ]
    }

    /// Average of all set criteria (ignores zeros). Returns nil if nothing was rated yet.
    var userRatingAverage: Double? {
        let vals = userRatingValues.filter { $0 > 0 }
        guard !vals.isEmpty else { return nil }
        let sum = vals.reduce(0, +)
        return Double(sum) / Double(vals.count)
    }

    /// Convenience: average rounded to 1 decimal (e.g. 4.2)
    var userRatingAverage1: Double? {
        guard let avg = userRatingAverage else { return nil }
        return (avg * 10).rounded() / 10
    }

    var status: ReadingStatus {
        get { ReadingStatus.fromPersisted(statusRawValue) ?? .toRead }
        set {
            statusRawValue = newValue.rawValue

            // Enforce rule: user ratings (and read range) only make sense for finished books.
            if newValue != .finished {
                readFrom = nil
                readTo = nil
                clearUserRatings()
            }
        }
    }

    /// True only when the book is marked as finished ("Gelesen").
    var canUserRate: Bool { status == .finished }

    /// Resets all user rating fields back to 0 (= nicht bewertet).
    func clearUserRatings() {
        userRatingPlot = 0
        userRatingCharacters = 0
        userRatingWritingStyle = 0
        userRatingAtmosphere = 0
        userRatingGenreFit = 0
        userRatingPresentation = 0
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
        // 0) user-selected local cover (highest priority) – legacy/fallback only.
        // The UI should primarily render `userCoverData`.
        if userCoverData == nil,
           let name = userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: name) {
            return fileURL.absoluteString
        }

        // 1) persisted remote thumbnail
        if let primary = toHTTPS(thumbnailURL) { return primary }

        // 2) persisted remote candidates
        for c in coverURLCandidates {
            if let https = toHTTPS(c) { return https }
        }

        // 3) OpenLibrary fallback (if ISBN)
        return openLibraryCoverURLCandidates.first
    }

    // Komfort: nil wie leeres Array behandeln
    var collectionsSafe: [BookCollection] {
        get { collections ?? [] }
        set { collections = newValue }
    }

    // Komfort: nil wie leeres Array behandeln
    var readingSessionsSafe: [ReadingSession] {
        get { readingSessions ?? [] }
        set { readingSessions = newValue }
    }

    // MARK: - Reading progress (aus Sessions + Seitenanzahl)

    /// Sum of all logged pages across sessions (ignores nil/<=0).
    var pagesReadTotalFromSessions: Int {
        readingSessionsSafe
            .compactMap { $0.pagesReadNormalized }
            .reduce(0, +)
    }

    /// Reading progress in the range 0…1.
    ///
    /// Rules:
    /// - If the book is marked as **finished**, progress is always 1.0.
    /// - If `pageCount` is missing/0 and the book is not finished, returns `nil`.
    /// - Otherwise: sum(pagesRead) / pageCount, clamped to 0…1.
    var readingProgressFraction: Double? {
        if status == .finished { return 1.0 }
        guard let total = pageCount, total > 0 else { return nil }
        let read = max(0, pagesReadTotalFromSessions)
        return min(1.0, max(0.0, Double(read) / Double(total)))
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

        // User-selected cover (local file) first
        if let name = userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: name) {
            add(fileURL.absoluteString)
        }

        add(toHTTPS(thumbnailURL))
        for s in coverURLCandidates { add(toHTTPS(s)) }
        for s in openLibraryCoverURLCandidates { add(s) }

        return out
    }

    /// Persists the winning cover URL for later ("instant" next time) and moves it to the front of candidates.
    func persistResolvedCoverURL(_ urlString: String) {
        let t = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        // Never persist local file URLs into CloudKit-synced string fields.
        // Those paths are device-local and would break cover rendering on other devices.
        if let u = URL(string: t), u.isFileURL { return }

        // Normalize to HTTPS when possible.
        let normalized = toHTTPS(t) ?? t

        // Persist as primary
        if thumbnailURL?.caseInsensitiveCompare(normalized) != .orderedSame {
            thumbnailURL = normalized
        }

        // Keep candidates list deduped + best-first
        var arr = coverURLCandidates
        arr.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        arr.insert(normalized, at: 0)
        coverURLCandidates = arr
    }
}
