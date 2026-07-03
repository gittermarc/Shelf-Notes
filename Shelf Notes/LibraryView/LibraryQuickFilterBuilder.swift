//
//  LibraryQuickFilterBuilder.swift
//  Shelf Notes
//
//  Pure builder for Smart Shelf tag and collection discovery shortcuts.
//

import Foundation

extension LibraryView {
    nonisolated enum LibraryQuickFilterBuilder {
        static let defaultTagLimit = 8
        static let defaultCollectionLimit = 6

        static func makeSnapshot(
            source: LibrarySourceSnapshot,
            tagLimit: Int = defaultTagLimit,
            collectionLimit: Int = defaultCollectionLimit
        ) -> LibraryQuickFilterSnapshot {
            makeSnapshot(
                books: source.books,
                tagLimit: tagLimit,
                collectionLimit: collectionLimit
            )
        }

        static func makeSnapshot(
            books: [LibrarySourceSnapshot.BookSnapshot],
            tagLimit: Int = defaultTagLimit,
            collectionLimit: Int = defaultCollectionLimit
        ) -> LibraryQuickFilterSnapshot {
            guard books.isEmpty == false else { return .empty }

            return LibraryQuickFilterSnapshot(
                tagItems: buildItems(
                    books: books,
                    limit: tagLimit,
                    kind: .tag,
                    systemImage: "tag"
                ) { book in
                    normalizedUniqueTags(for: book)
                },
                collectionItems: buildItems(
                    books: books,
                    limit: collectionLimit,
                    kind: .collection,
                    systemImage: "rectangle.stack"
                ) { book in
                    normalizedUniqueCollectionNames(for: book)
                }
            )
        }

        private static func buildItems(
            books: [LibrarySourceSnapshot.BookSnapshot],
            limit: Int,
            kind: LibraryQuickFilterItem.Kind,
            systemImage: String,
            values: (LibrarySourceSnapshot.BookSnapshot) -> [String]
        ) -> [LibraryQuickFilterItem] {
            let limit = max(0, limit)
            guard limit > 0 else { return [] }

            var buckets: [String: Bucket] = [:]

            for book in books {
                for value in values(book) {
                    let key = value.lowercased()
                    var bucket = buckets[key] ?? Bucket(title: value, count: 0)
                    bucket.count += 1
                    if shouldPreferDisplayTitle(value, over: bucket.title) {
                        bucket.title = value
                    }
                    buckets[key] = bucket
                }
            }

            return buckets.map { key, bucket in
                LibraryQuickFilterItem(
                    kind: kind,
                    title: bucket.title,
                    normalizedValue: key,
                    count: bucket.count,
                    systemImage: systemImage
                )
            }
            .sorted(by: compareItems)
            .prefix(limit)
            .map { $0 }
        }

        private static func normalizedUniqueTags(
            for book: LibrarySourceSnapshot.BookSnapshot
        ) -> [String] {
            uniqueNormalizedValues(book.tags.map(normalizeTagString))
        }

        private static func normalizedUniqueCollectionNames(
            for book: LibrarySourceSnapshot.BookSnapshot
        ) -> [String] {
            uniqueNormalizedValues(book.collectionNames)
        }

        private static func uniqueNormalizedValues(_ values: [String]) -> [String] {
            var seen: Set<String> = []
            var result: [String] = []
            result.reserveCapacity(values.count)

            for value in values {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.lowercased()
                guard trimmed.isEmpty == false, seen.contains(key) == false else { continue }
                seen.insert(key)
                result.append(trimmed)
            }

            return result
        }

        private static func compareItems(
            _ lhs: LibraryQuickFilterItem,
            _ rhs: LibraryQuickFilterItem
        ) -> Bool {
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }

            let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.normalizedValue < rhs.normalizedValue
        }

        private static func shouldPreferDisplayTitle(_ candidate: String, over current: String) -> Bool {
            if current.isEmpty { return true }
            if candidate == current { return false }
            if candidate.count != current.count { return candidate.count < current.count }
            return candidate.localizedCaseInsensitiveCompare(current) == .orderedAscending
        }

        private struct Bucket {
            var title: String
            var count: Int
        }
    }
}
