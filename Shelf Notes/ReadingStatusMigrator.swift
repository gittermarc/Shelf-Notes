//
//  ReadingStatusMigrator.swift
//  Shelf Notes
//

import Foundation
import SwiftData

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
            for book in books {
                guard let mapped = ReadingStatus.fromPersisted(book.statusRawValue) else { continue }
                if book.statusRawValue != mapped.rawValue {
                    book.statusRawValue = mapped.rawValue
                    didChange = true
                }
            }

            if didChange {
                _ = modelContext.saveWithDiagnostics()
            }

            defaults.set(true, forKey: migrationKey)
        } catch {
            #if DEBUG
            print("ReadingStatusMigrator failed: \(error)")
            #endif
        }
    }
}
