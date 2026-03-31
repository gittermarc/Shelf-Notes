//
//  BookImportViewModel+Search.swift
//  Shelf Notes
//
//  Search-specific query helpers kept separate from task orchestration.
//

import Foundation

@MainActor
extension BookImportViewModel {

    func currentQueryOptions() -> GoogleBooksQueryOptions {
        let builder = BookImportQueryBuilder(scope: scope, category: category)
        return builder.makeQueryOptions(language: language, sortOption: sortOption, apiFilter: apiFilter)
    }

    /// Splits a query of the form "A OR B" (outside quotes) into its parts.
    ///
    /// We use this for certain "Für dich" seeds to avoid relying on undocumented OR parsing.
    func splitTopLevelOR(_ query: String) -> [String]? {
        let needle = " OR "
        guard query.contains(needle) else { return nil }

        var parts: [String] = []
        var current = ""
        var inQuotes = false

        var i = query.startIndex
        while i < query.endIndex {
            let ch = query[i]
            if ch == "\"" {
                inQuotes.toggle()
                current.append(ch)
                i = query.index(after: i)
                continue
            }

            if !inQuotes, query[i...].hasPrefix(needle) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
                current = ""
                i = query.index(i, offsetBy: needle.count)
                continue
            }

            current.append(ch)
            i = query.index(after: i)
        }

        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty {
            parts.append(last)
        }

        return parts.count >= 2 ? parts : nil
    }

    func interleavingUniqueVolumes(lists: [[GoogleBookVolume]]) -> [GoogleBookVolume] {
        guard !lists.isEmpty else { return [] }

        var out: [GoogleBookVolume] = []
        out.reserveCapacity(lists.reduce(0) { $0 + $1.count })

        var seen: Set<String> = []
        let maxLen = lists.map { $0.count }.max() ?? 0

        for i in 0..<maxLen {
            for list in lists {
                guard i < list.count else { continue }
                let volume = list[i]
                if seen.insert(volume.id).inserted {
                    out.append(volume)
                }
            }
        }

        return out
    }
}
