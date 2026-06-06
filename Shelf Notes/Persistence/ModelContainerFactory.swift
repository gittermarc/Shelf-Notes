//
//  ModelContainerFactory.swift
//  Shelf Notes
//
//  Builds SwiftData containers without coupling store policy to app UI.
//

import Foundation
import SwiftData

enum ModelContainerFactory {
    static var schema: Schema {
        Schema([
            Book.self,
            ReadingAttempt.self,
            ReadingSession.self,
            ReadingGoal.self,
            BookCollection.self,
            ChallengeRecord.self
        ])
    }

    // MARK: - Store separation

    /// We intentionally keep the CloudKit-backed store and the explicit local-only store
    /// in separate persistent stores. This avoids accidental store mixing when a user
    /// launches the app in local-only fallback mode and later goes back to CloudKit.
    ///
    /// This does mean local-only mode has its own local data set.
    private enum StoreName {
        static let cloud = "ShelfNotesCloud"
        static let local = "ShelfNotesLocal"
    }

    private static func storeURL(for storeBaseName: String) throws -> URL {
        // SwiftData uses a directory-based store in Application Support.
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        // Keep SwiftData stores in an app-scoped folder to avoid clutter.
        let dir = appSupport
            .appendingPathComponent("ShelfNotes", isDirectory: true)
            .appendingPathComponent("SwiftData", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)

        return dir.appendingPathComponent("\(storeBaseName).store")
    }

    static func makeContainer(mode: StorageMode) throws -> ModelContainer {
        switch mode {
        case .cloudKit:
            // CloudKit sync via iCloud uses the container from the app entitlements.
            let cloudURL = try storeURL(for: StoreName.cloud)
            let config = ModelConfiguration(
                StoreName.cloud,
                schema: schema,
                url: cloudURL,
                allowsSave: true,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [config])

        case .localOnly:
            // Local persistent store without CloudKit.
            // IMPORTANT: This is an explicit, user-chosen fallback to avoid silent data divergence.
            let localURL = try storeURL(for: StoreName.local)
            let config = ModelConfiguration(
                StoreName.local,
                schema: schema,
                url: localURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])

        case .inMemory:
            // Emergency fallback: runs in-memory only.
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }
    }
}
