//
//  BookImportCategoryNormalizer.swift
//  Shelf Notes
//
//  Helper for robust category filtering in the Google Books import flow.
//
//  Google Books categories are often hierarchical and/or combined, and appear in mixed DE/EN forms.
//  Example strings:
//  - "Business & Economics / General"
//  - "Biography und Autobiografie"
//  - "Fiction / Mystery & Detective / General"
//

import Foundation

enum BookImportCategoryNormalizer {

    // MARK: - Profile

    /// Canonical representation of a category token.
    /// - `key`: stable identifier for matching/counting
    /// - `display`: what we show in the picker
    /// - `queryFragment`: the safest Google Books query fragment (may be a `subject:` filter, or a quoted phrase)
    /// - `broadTerm`: fallback broad term for matching and for query building
    struct Profile: Hashable {
        let key: String
        let display: String
        let queryFragment: String?
        let broadTerm: String
    }

    // MARK: - Public API

    /// Split a raw category string into usable tokens.
    ///
    /// Examples:
    /// - "Business & Economics / General" -> ["Business", "Economics"]
    /// - "Biography und Autobiografie" -> ["Biography", "Autobiografie"]
    /// - "Fiction / Mystery & Detective / General" -> ["Mystery", "Detective"]
    static func extractTokens(from raw: String) -> [String] {
        let t0 = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t0.isEmpty else { return [] }

        // Split hierarchy
        let parts = t0
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Drop ultra generic parts
        let filtered = parts.filter { part in
            let lower = part.lowercased()
            return lower != "general" && lower != "fiction" && lower != "nonfiction"
        }

        // Split connectors inside each part (Business & Economics, Biography und Autobiografie, Mystery & Detective)
        var tokens: [String] = []
        for part in filtered.isEmpty ? [t0] : filtered {
            tokens.append(contentsOf: splitConnectors(part))
        }

        // Final cleanup + drop short noise
        return tokens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }

    /// Turn a raw string (or token) into canonical profiles.
    static func profiles(from raw: String) -> [Profile] {
        extractTokens(from: raw)
            .compactMap { normalizeToken($0) }
    }

    /// Build a query fragment for the currently selected category.
    ///
    /// We avoid forcing `subject:"<raw>"` when the raw category is combined/locale-specific.
    /// Instead we expand to OR queries of stable mapped categories or broad text terms.
    ///
    /// Examples:
    /// - "Biography & Autobiography" -> (subject:biography OR subject:autobiography)
    /// - "Business und Economics" -> (subject:business OR subject:economics)
    static func queryFragment(forSelectedCategory selected: String) -> String? {
        let ps = profiles(from: selected)
        guard !ps.isEmpty else { return nil }

        let fragments: [String] = ps.map { p in
            if let q = p.queryFragment, !q.isEmpty {
                return q
            }
            return quoteIfNeeded(p.broadTerm)
        }

        if fragments.count == 1 {
            return fragments[0]
        }

        // OR-expansion keeps results flowing even if Google's subject taxonomy doesn't match perfectly.
        return "(" + fragments.joined(separator: " OR ") + ")"
    }

    /// Matching helper used by local filtering.
    /// Returns true when the selected category matches any of the volume's categories.
    static func matches(volumeCategories: [String], selectedCategory: String) -> Bool {
        let selectedProfiles = profiles(from: selectedCategory)
        guard !selectedProfiles.isEmpty else {
            return fallbackSubstringMatch(volumeCategories: volumeCategories, selected: selectedCategory)
        }

        let selectedKnownKeys = Set(selectedProfiles.map { $0.key }.filter { !$0.hasPrefix("free:") })
        let selectedBroad = selectedProfiles.map { $0.broadTerm }.filter { !$0.isEmpty }

        // 1) Prefer stable key matching for known categories.
        if !selectedKnownKeys.isEmpty {
            var volumeKeys: Set<String> = []
            for raw in volumeCategories {
                for p in profiles(from: raw) {
                    if !p.key.hasPrefix("free:") {
                        volumeKeys.insert(p.key)
                    }
                }
            }
            if !selectedKnownKeys.isDisjoint(with: volumeKeys) {
                return true
            }
        }

        // 2) Fallback: broad substring matching (diacritic-insensitive).
        return broadSubstringMatch(volumeCategories: volumeCategories, selectedBroadTerms: selectedBroad)
    }

    /// Builds the category picker list (display strings), based on the fetched volumes.
    static func computeAvailableCategoryDisplays(from volumeCategories: [[String]], includeSelected selected: String) -> [String] {
        var counts: [String: (display: String, count: Int)] = [:]

        func add(profile: Profile) {
            let key = profile.key
            if let existing = counts[key] {
                counts[key] = (existing.display, existing.count + 1)
            } else {
                counts[key] = (profile.display, 1)
            }
        }

        for cats in volumeCategories {
            for raw in cats {
                for p in profiles(from: raw) {
                    add(profile: p)
                }
            }
        }

        // Make sure selected category stays visible even if counts are low.
        let tSel = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tSel.isEmpty {
            for p in profiles(from: tSel) {
                add(profile: p)
            }
        }

        return counts.values
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.display.localizedCaseInsensitiveCompare(b.display) == .orderedAscending
            }
            .map { $0.display }
    }

    // MARK: - Normalization

    private static func normalizeToken(_ token: String) -> Profile? {
        let raw = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let canon = canonicalKey(from: raw)
        if let mapped = knownMap[canon] {
            return mapped
        }

        let broad = broadTextTerm(from: raw)
        guard broad.count >= 3 else { return nil }

        return Profile(
            key: "free:\(broad.lowercased())",
            display: prettify(broad),
            queryFragment: nil,
            broadTerm: broad
        )
    }

    private static var knownMap: [String: Profile] {
        [
            // Biografie
            "biography": Profile(key: "biography", display: "Biografien", queryFragment: "subject:biography", broadTerm: "biography"),
            "biografien": Profile(key: "biography", display: "Biografien", queryFragment: "subject:biography", broadTerm: "biography"),
            "biografie": Profile(key: "biography", display: "Biografien", queryFragment: "subject:biography", broadTerm: "biography"),

            // Autobiografie
            "autobiography": Profile(key: "autobiography", display: "Autobiografien", queryFragment: "subject:autobiography", broadTerm: "autobiography"),
            "autobiografien": Profile(key: "autobiography", display: "Autobiografien", queryFragment: "subject:autobiography", broadTerm: "autobiography"),
            "autobiografie": Profile(key: "autobiography", display: "Autobiografien", queryFragment: "subject:autobiography", broadTerm: "autobiography"),

            // Business / Economics
            "business": Profile(key: "business", display: "Business", queryFragment: "subject:business", broadTerm: "business"),
            "wirtschaft": Profile(key: "business", display: "Business", queryFragment: "subject:business", broadTerm: "business"),
            "economics": Profile(key: "economics", display: "Economics", queryFragment: "subject:economics", broadTerm: "economics"),
            "okonomie": Profile(key: "economics", display: "Economics", queryFragment: "subject:economics", broadTerm: "economics"),
            "okonomik": Profile(key: "economics", display: "Economics", queryFragment: "subject:economics", broadTerm: "economics"),
            "volkswirtschaft": Profile(key: "economics", display: "Economics", queryFragment: "subject:economics", broadTerm: "economics"),

            // Common genres
            "thriller": Profile(key: "thriller", display: "Thriller", queryFragment: "subject:thriller", broadTerm: "thriller"),
            "crime": Profile(key: "crime", display: "Krimi", queryFragment: "subject:crime", broadTerm: "crime"),
            "krimi": Profile(key: "crime", display: "Krimi", queryFragment: "subject:crime", broadTerm: "crime"),
            "fantasy": Profile(key: "fantasy", display: "Fantasy", queryFragment: "subject:fantasy", broadTerm: "fantasy"),
            "horror": Profile(key: "horror", display: "Horror", queryFragment: "subject:horror", broadTerm: "horror"),
            "romance": Profile(key: "romance", display: "Romance", queryFragment: "subject:romance", broadTerm: "romance"),
            "true crime": Profile(key: "true crime", display: "True Crime", queryFragment: "\"true crime\"", broadTerm: "true crime"),

            // Sci-Fi
            "science fiction": Profile(key: "science fiction", display: "Sci-Fi", queryFragment: "subject:\"science fiction\"", broadTerm: "science fiction"),
            "sci fi": Profile(key: "science fiction", display: "Sci-Fi", queryFragment: "subject:\"science fiction\"", broadTerm: "science fiction"),
            "scifi": Profile(key: "science fiction", display: "Sci-Fi", queryFragment: "subject:\"science fiction\"", broadTerm: "science fiction"),
        ]
    }

    // MARK: - Helpers

    private static func splitConnectors(_ s: String) -> [String] {
        let normalized = " " + s + " "

        // Replace common connectors with a delimiter
        let connectors = [
            " & ", "&",
            " und ", " and ",
            " + ", "+",
            ",", " · ", "•"
        ]

        var work = normalized
        for c in connectors {
            work = work.replacingOccurrences(of: c, with: " | ")
        }

        return work
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Normalize for dictionary matching: lowercased, diacritic-insensitive, punctuation -> spaces.
    private static func canonicalKey(from raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = folded.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let s = String(scalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return s
    }

    private static func broadTextTerm(from raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let s = String(scalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }

    private static func prettify(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return s }
        if t.contains(where: { $0.isUppercase }) { return t }
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    private static func quoteIfNeeded(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return cleaned }
        if cleaned.contains(" ") {
            return "\"\(cleaned)\""
        }
        return cleaned
    }

    private static func fallbackSubstringMatch(volumeCategories: [String], selected: String) -> Bool {
        let needle = selected
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !needle.isEmpty else { return true }

        for raw in volumeCategories {
            let hay = raw
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            if hay.contains(needle) { return true }
        }
        return false
    }

    private static func broadSubstringMatch(volumeCategories: [String], selectedBroadTerms: [String]) -> Bool {
        let needles = selectedBroadTerms
            .map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() }
            .filter { !$0.isEmpty }

        guard !needles.isEmpty else { return false }

        for raw in volumeCategories {
            let hay = raw
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            if needles.contains(where: { hay.contains($0) }) {
                return true
            }
        }
        return false
    }
}
