//
//  Shelf_NotesApp.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//

import SwiftUI
import SwiftData

@main
struct Shelf_NotesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            ReadingGoal.self
        ])

        // CloudKit sync via iCloud (uses the container from your entitlements)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
