//
//  TagsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tags Tab (counts + tap to filter)
struct TagsView: View {
    @Query private var books: [Book]

    var body: some View {
        NavigationStack {
            List {
                if tagCounts.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Tags",
                        systemImage: "tag",
                        description: Text("Füge Tags bei einem Buch hinzu, dann tauchen sie hier auf.")
                    )
                } else {
                    ForEach(tagCounts, id: \.tag) { entry in
                        NavigationLink {
                            LibraryView(initialTag: entry.tag)
                        } label: {
                            HStack {
                                Text("#\(entry.tag)")
                                Spacer()
                                Text("\(entry.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
        }
    }

    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in books {
            for t in b.tags {
                let normalized = normalizeTagString(t)
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }
        return counts
            .map { ($0.key, $0.value) }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.localizedCaseInsensitiveCompare(b.0) == .orderedAscending
            }
    }
}
