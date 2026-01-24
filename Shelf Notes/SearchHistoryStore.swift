//
/*  SearchHistoryStore.swift
    Shelf Notes

    Small helper to persist a string history list as JSON in UserDefaults.
*/

import Foundation

struct SearchHistoryStore {
    let key: String
    let maxItems: Int

    init(key: String, maxItems: Int = 10) {
        self.key = key
        self.maxItems = maxItems
    }

    func load() -> [String] {
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    func save(_ items: [String]) {
        let trimmed = Array(items.prefix(maxItems))
        guard let data = try? JSONEncoder().encode(trimmed),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(json, forKey: key)
    }

    func add(_ term: String) -> [String] {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return load() }

        var items = load()
        items.removeAll { $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        items.insert(normalized, at: 0)
        save(items)
        return items
    }

    func clear() {
        save([])
    }
}
