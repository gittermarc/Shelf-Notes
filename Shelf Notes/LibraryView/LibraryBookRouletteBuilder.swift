//
//  LibraryBookRouletteBuilder.swift
//  Shelf Notes
//
//  Pure builder for the Smart Shelf book roulette.
//

import Foundation

extension LibraryView {
    nonisolated enum LibraryBookRouletteBuilder {
        static let defaultCandidateLimit = 24

        static func makeRoulette(
            source: LibrarySourceSnapshot,
            selectedTag: String? = nil,
            selectedCollectionName: String? = nil,
            candidateLimit: Int = defaultCandidateLimit
        ) -> LibraryBookRoulette {
            makeRoulette(
                books: source.books,
                selectedTag: selectedTag,
                selectedCollectionName: selectedCollectionName,
                candidateLimit: candidateLimit
            )
        }

        static func makeRoulette(
            books: [LibrarySourceSnapshot.BookSnapshot],
            selectedTag: String? = nil,
            selectedCollectionName: String? = nil,
            candidateLimit: Int = defaultCandidateLimit
        ) -> LibraryBookRoulette {
            guard books.isEmpty == false else { return .empty }

            let normalizedTag = normalizedFilterValue(selectedTag)
            let normalizedCollectionName = normalizedFilterValue(selectedCollectionName)
            let limit = max(0, candidateLimit)

            guard limit > 0 else { return .empty }

            let candidates = books.compactMap { book -> LibraryBookRoulette.Candidate? in
                guard book.status == .toRead else { return nil }

                let title = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard title.isEmpty == false else { return nil }

                if let normalizedTag,
                   matchesTag(book, normalizedTag: normalizedTag) == false {
                    return nil
                }

                if let normalizedCollectionName,
                   matchesCollection(book, normalizedCollectionName: normalizedCollectionName) == false {
                    return nil
                }

                return LibraryBookRoulette.Candidate(
                    id: book.id,
                    title: title,
                    author: book.author.trimmingCharacters(in: .whitespacesAndNewlines),
                    tags: normalizedDisplayTags(from: book.tags),
                    collectionNames: book.collectionNames,
                    createdAt: book.createdAt
                )
            }
            .sorted(by: compareCandidates)

            return LibraryBookRoulette(candidates: Array(candidates.prefix(limit)))
        }

        private static func matchesTag(
            _ book: LibrarySourceSnapshot.BookSnapshot,
            normalizedTag: String
        ) -> Bool {
            book.tags.contains { rawTag in
                normalizedFilterValue(normalizeTagString(rawTag)) == normalizedTag
            }
        }

        private static func matchesCollection(
            _ book: LibrarySourceSnapshot.BookSnapshot,
            normalizedCollectionName: String
        ) -> Bool {
            book.collectionNames.contains { collectionName in
                normalizedFilterValue(collectionName) == normalizedCollectionName
            }
        }

        private static func normalizedDisplayTags(from tags: [String]) -> [String] {
            var seen: Set<String> = []
            var result: [String] = []
            result.reserveCapacity(tags.count)

            for rawTag in tags {
                let tag = normalizeTagString(rawTag)
                let key = tag.lowercased()
                guard tag.isEmpty == false, seen.contains(key) == false else { continue }
                seen.insert(key)
                result.append(tag)
            }

            return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        private static func compareCandidates(
            _ lhs: LibraryBookRoulette.Candidate,
            _ rhs: LibraryBookRoulette.Candidate
        ) -> Bool {
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }

            let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        private static func normalizedFilterValue(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed.lowercased()
        }
    }
}
