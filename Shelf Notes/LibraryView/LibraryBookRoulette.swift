//
//  LibraryBookRoulette.swift
//  Shelf Notes
//
//  Value-only model for the Smart Shelf book roulette.
//

import Foundation

extension LibraryView {
    nonisolated struct LibraryBookRoulette: Equatable {
        let candidates: [Candidate]

        static let empty = LibraryBookRoulette(candidates: [])

        var isEmpty: Bool {
            candidates.isEmpty
        }

        var candidateIDs: [UUID] {
            candidates.map(\.id)
        }

        func candidate(for id: UUID?) -> Candidate? {
            guard let id else { return nil }
            return candidates.first { $0.id == id }
        }

        func drawCandidate(
            excluding currentID: UUID? = nil,
            randomIndex: (Int) -> Int
        ) -> Candidate? {
            guard candidates.isEmpty == false else { return nil }

            let pool: [Candidate]
            if let currentID, candidates.count > 1 {
                pool = candidates.filter { $0.id != currentID }
            } else {
                pool = candidates
            }

            guard pool.isEmpty == false else { return nil }

            let rawIndex = randomIndex(pool.count)
            let normalizedIndex = ((rawIndex % pool.count) + pool.count) % pool.count
            return pool[normalizedIndex]
        }

        nonisolated struct Candidate: Equatable, Identifiable {
            let id: UUID
            let title: String
            let author: String
            let tags: [String]
            let collectionNames: [String]
            let createdAt: Date
        }
    }
}
