//
//  LibrarySmartFilter.swift
//  Shelf Notes
//
//  Small, testable Smart Shelf filters for the library derived-state pipeline.
//

import Foundation

extension LibraryView {
    nonisolated enum LibrarySmartFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
        case withoutCover
        case withoutTags
        case withoutPageCount
        case unrated
        case withNotes
        case rereads
        case longInactive

        var id: String { rawValue }

        static var maintenanceFilters: [LibrarySmartFilter] {
            [
                .withoutCover,
                .withoutTags,
                .withoutPageCount,
                .unrated,
                .rereads,
                .longInactive
            ]
        }

        var title: String {
            switch self {
            case .withoutCover:
                return "Ohne Cover"
            case .withoutTags:
                return "Ohne Tags"
            case .withoutPageCount:
                return "Ohne Seitenzahl"
            case .unrated:
                return "Unbewertet"
            case .withNotes:
                return "Mit Notizen"
            case .rereads:
                return "Re-Reads"
            case .longInactive:
                return "Lange nicht gelesen"
            }
        }

        var systemImage: String {
            switch self {
            case .withoutCover:
                return "photo"
            case .withoutTags:
                return "tag"
            case .withoutPageCount:
                return "number"
            case .unrated:
                return "star"
            case .withNotes:
                return "note.text"
            case .rereads:
                return "arrow.triangle.2.circlepath"
            case .longInactive:
                return "clock.arrow.circlepath"
            }
        }

        var maintenanceTitle: String {
            switch self {
            case .withoutCover:
                return "ohne Cover"
            case .withoutTags:
                return "ohne Tags"
            case .withoutPageCount:
                return "ohne Seitenzahl"
            case .unrated:
                return "unbewertet"
            case .withNotes:
                return "mit Notizen"
            case .rereads:
                return "Re-Reads"
            case .longInactive:
                return "lange ruhig"
            }
        }

        func matches(
            _ book: LibrarySourceSnapshot.BookSnapshot,
            longInactiveCutoff: Date?
        ) -> Bool {
            switch self {
            case .withoutCover:
                return book.hasCover == false
            case .withoutTags:
                let hasAnyTag = book.tags.contains { tag in
                    tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                }
                return hasAnyTag == false
            case .withoutPageCount:
                return book.pageCount == nil
            case .unrated:
                return book.status == .finished && book.hasUserRating == false
            case .withNotes:
                return book.hasNotes
            case .rereads:
                return book.isRereading || book.completedReadingAttemptCount > 1
            case .longInactive:
                guard book.status == .reading, let longInactiveCutoff else { return false }
                let activityDate = book.lastSessionAt ?? book.readFrom ?? book.createdAt
                return activityDate < longInactiveCutoff
            }
        }
    }
}
