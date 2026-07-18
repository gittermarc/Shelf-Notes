//
//  LibraryWidgetCoverExporter.swift
//  Shelf Notes
//
//  Exports a small, local-only cover set for the Library Home Screen widget.
//  The widget extension reads these JPEG files from the App Group and never performs network work.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum LibraryWidgetCoverFilePolicy {
    static let directoryName = "LibraryWidgetCovers"
    static let filePrefix = "widget_cover_"
    static let fileExtension = "jpg"

    static func directoryURL(in containerURL: URL) -> URL {
        containerURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    static func fileName(bookID: UUID) -> String {
        "\(filePrefix)\(bookID.uuidString).\(fileExtension)"
    }

    static func fileURL(bookID: UUID, in containerURL: URL) -> URL {
        directoryURL(in: containerURL).appendingPathComponent(fileName(bookID: bookID), isDirectory: false)
    }
}

@MainActor
enum LibraryWidgetCoverExporter {
    static func exportCoversAndUpdateAvailability(
        in snapshot: LibraryWidgetSnapshot,
        books: [Book],
        directoryURLProvider: () -> URL? = { LiveActivitySharedStore.appGroupContainerURL },
        fileManager: FileManager = .default
    ) -> LibraryWidgetSnapshot {
        guard let containerURL = directoryURLProvider() else {
            return snapshot.withCoverAvailability(availableBookIDs: [])
        }

        let requestedBookIDs = Set(
            snapshot.displayedBooksForWidgetCoverExport
                .filter(\.hasCover)
                .map(\.id)
        )
        guard !requestedBookIDs.isEmpty else {
            cleanupUnusedCovers(
                keeping: [],
                containerURL: containerURL,
                fileManager: fileManager
            )
            return snapshot.withCoverAvailability(availableBookIDs: [])
        }

        let booksByID = books.reduce(into: [UUID: Book]()) { partialResult, book in
            partialResult[book.id] = book
        }
        let directoryURL = LibraryWidgetCoverFilePolicy.directoryURL(in: containerURL)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var availableBookIDs = Set<UUID>()
        for bookID in requestedBookIDs {
            let destinationURL = LibraryWidgetCoverFilePolicy.fileURL(bookID: bookID, in: containerURL)
            if let book = booksByID[bookID],
               let sourceData = coverSourceData(for: book),
               let jpegData = downsampleToWidgetJPEG(sourceData) {
                do {
                    try jpegData.write(to: destinationURL, options: [.atomic])
                    availableBookIDs.insert(bookID)
                    continue
                } catch {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        availableBookIDs.insert(bookID)
                    }
                    continue
                }
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                availableBookIDs.insert(bookID)
            }
        }

        cleanupUnusedCovers(
            keeping: availableBookIDs,
            containerURL: containerURL,
            fileManager: fileManager
        )

        return snapshot.withCoverAvailability(availableBookIDs: availableBookIDs)
    }

    static func cleanupUnusedCovers(
        keeping keptBookIDs: Set<UUID>,
        containerURL: URL,
        fileManager: FileManager = .default
    ) {
        let directoryURL = LibraryWidgetCoverFilePolicy.directoryURL(in: containerURL)
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        let keptFileNames = Set(keptBookIDs.map { LibraryWidgetCoverFilePolicy.fileName(bookID: $0) })
        for fileURL in fileURLs {
            let fileName = fileURL.lastPathComponent
            guard fileName.hasPrefix(LibraryWidgetCoverFilePolicy.filePrefix),
                  fileURL.pathExtension.lowercased() == LibraryWidgetCoverFilePolicy.fileExtension,
                  !keptFileNames.contains(fileName)
            else {
                continue
            }

            try? fileManager.removeItem(at: fileURL)
        }
    }

    private static func coverSourceData(for book: Book) -> Data? {
        if let data = book.userCoverData, !data.isEmpty {
            return data
        }

        if let fileName = book.userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: fileName),
           let data = try? Data(contentsOf: fileURL),
           !data.isEmpty {
            return data
        }

        for candidate in book.coverCandidatesAll {
            guard let url = URL(string: candidate) else { continue }
            if url.isFileURL {
                if let data = try? Data(contentsOf: url), !data.isEmpty {
                    return data
                }
            } else if let data = ImageDiskCache.shared.data(for: url), !data.isEmpty {
                return data
            }
        }

        return nil
    }

    private static func downsampleToWidgetJPEG(_ data: Data) -> Data? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 520
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.84
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

private extension LibraryWidgetSnapshot {
    var displayedBooksForWidgetCoverExport: [LibraryWidgetBookSnapshot] {
        var result: [LibraryWidgetBookSnapshot] = []
        if let currentBook {
            result.append(currentBook)
        }

        for item in recentShelfItems where !result.contains(where: { $0.id == item.id }) {
            result.append(item)
        }

        return result
    }

    func withCoverAvailability(availableBookIDs: Set<UUID>) -> LibraryWidgetSnapshot {
        LibraryWidgetSnapshot(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            state: state,
            totalBooks: totalBooks,
            readBooks: readBooks,
            readingBooks: readingBooks,
            wantToReadBooks: wantToReadBooks,
            currentBook: currentBook.map { book in
                book.withCoverAvailability(availableBookIDs.contains(book.id))
            },
            yearlyGoal: yearlyGoal,
            last7DaysReadingMinutes: last7DaysReadingMinutes,
            last7DaysReadingDays: last7DaysReadingDays,
            currentReadingStreakDays: currentReadingStreakDays,
            recentShelfItems: recentShelfItems.map { item in
                item.withCoverAvailability(availableBookIDs.contains(item.id))
            },
            privacy: privacy
        )
    }
}

private extension LibraryWidgetBookSnapshot {
    func withCoverAvailability(_ isAvailable: Bool) -> LibraryWidgetBookSnapshot {
        LibraryWidgetBookSnapshot(
            id: id,
            title: title,
            author: author,
            kind: kind,
            statusRawValue: statusRawValue,
            pageCount: pageCount,
            pagesRead: pagesRead,
            remainingPages: remainingPages,
            progressFraction: progressFraction,
            progressNativeValue: progressNativeValue,
            progressLocator: progressLocator,
            mediumRawValue: mediumRawValue,
            providerRawValue: providerRawValue,
            progressUnitRawValue: progressUnitRawValue,
            referenceDate: referenceDate,
            hasCover: hasCover && isAvailable,
            coverRevision: hasCover && isAvailable ? coverRevision : nil
        )
    }
}
