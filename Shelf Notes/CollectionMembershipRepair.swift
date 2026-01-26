//
//  CollectionMembershipRepair.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 26.01.26.
//

import Foundation
import SwiftData

/// One-time repair for Book <-> Collection membership.
///
/// Why:
/// - Older builds could end up with "drift" (Book references Collection, but Collection doesn't reference Book, or vice versa),
///   because both sides were manually mutated.
/// - SwiftData can keep inverse relationships in sync automatically, so we enforce a single source of truth going forward.
/// - This repair runs once (per persistent store scope) to unify & dedupe existing data.
enum CollectionMembershipRepair {

    private static let repairKeyBase = "did_repair_collection_memberships_v1"

    private static func scopedRepairKey(_ scope: String) -> String {
        let t = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return repairKeyBase }
        return "\(repairKeyBase)_\(t)"
    }

    /// Runs the repair once per `scope`.
    ///
    /// `scope` should identify the active persistent store (e.g. "cloudKit" vs "localOnly").
    /// This matters because Shelf Notes intentionally keeps these stores separate.
    @MainActor
    static func repairIfNeeded(modelContext: ModelContext, scope: String) async {
        let defaults = UserDefaults.standard
        let repairKey = scopedRepairKey(scope)
        guard defaults.bool(forKey: repairKey) == false else { return }

        do {
            let books = try modelContext.fetch(FetchDescriptor<Book>())
            let collections = try modelContext.fetch(FetchDescriptor<BookCollection>())

            var didChange = false

            // 1) Deduplicate both sides (defensive)
            for b in books {
                let deduped = dedupCollections(b.collectionsSafe)
                if deduped.count != b.collectionsSafe.count {
                    b.collectionsSafe = deduped
                    didChange = true
                }
            }

            for c in collections {
                let deduped = dedupBooks(c.booksSafe)
                if deduped.count != c.booksSafe.count {
                    c.booksSafe = deduped
                    didChange = true
                }
            }

            // 2) Symmetry: Book -> Collection
            for b in books {
                for c in b.collectionsSafe {
                    if !c.booksSafe.contains(where: { $0.id == b.id }) {
                        var arr = c.booksSafe
                        arr.append(b)
                        c.booksSafe = arr
                        c.updatedAt = Date()
                        didChange = true
                    }
                }
            }

            // 3) Symmetry: Collection -> Book
            for c in collections {
                for b in c.booksSafe {
                    if !b.collectionsSafe.contains(where: { $0.id == c.id }) {
                        var arr = b.collectionsSafe
                        arr.append(c)
                        b.collectionsSafe = arr
                        didChange = true
                    }
                }
            }

            if didChange {
                _ = modelContext.saveWithDiagnostics()
            }

            defaults.set(true, forKey: repairKey)
        } catch {
            // If this fails, we will retry next launch (for this scope).
            #if DEBUG
            print("CollectionMembershipRepair failed (\(scope)): \(error)")
            #endif
        }
    }

    private static func dedupBooks(_ input: [Book]) -> [Book] {
        var seen = Set<UUID>()
        var out: [Book] = []
        out.reserveCapacity(input.count)

        for b in input {
            if seen.insert(b.id).inserted {
                out.append(b)
            }
        }
        return out
    }

    private static func dedupCollections(_ input: [BookCollection]) -> [BookCollection] {
        var seen = Set<UUID>()
        var out: [BookCollection] = []
        out.reserveCapacity(input.count)

        for c in input {
            if seen.insert(c.id).inserted {
                out.append(c)
            }
        }
        return out
    }
}
