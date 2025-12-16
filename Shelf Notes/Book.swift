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
    @Attribute(.unique) var id: UUID = UUID()

    // Core
    var title: String = ""
    var author: String = ""
    var createdAt: Date = Date()
    var statusRawValue: String = ReadingStatus.toRead.rawValue
    var tags: [String] = []
    var notes: String = ""

    // Reading period (only meaningful for finished books)
    var readFrom: Date?
    var readTo: Date?

    // Imported metadata (optional / defaults)
    var googleVolumeID: String?
    var isbn13: String?
    var thumbnailURL: String?
    var publisher: String?
    var publishedDate: String?
    var pageCount: Int?
    var language: String?
    var categories: [String] = []
    var bookDescription: String = ""

    var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusRawValue) ?? .toRead }
        set { statusRawValue = newValue.rawValue }
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
    }
}
