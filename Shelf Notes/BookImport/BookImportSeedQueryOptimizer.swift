//
//  BookImportSeedQueryOptimizer.swift
//  Shelf Notes
//
//  Improves "seed"/operator-heavy queries when a specific language is selected.
//
//  Problem:
//  - Seeds like `subject:autobiography` work great without langRestrict.
//  - With langRestrict=de they can collapse to very few (or 0) results because the
//    category taxonomy terms are inconsistent across locales.
//
//  Strategy:
//  - When the user selected a specific language (e.g. Deutsch), we rewrite `subject:` parts
//    into broad, localized free-text terms.
//  - This keeps the intent (topic) but prevents "0 results" frustration.
//

import Foundation

enum BookImportSeedQueryOptimizer {

    /// Returns the query unchanged unless it contains `subject:` and a specific language is selected.
    static func optimize(query: String, language: BookImportLanguageOption) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return query }

        // Don't touch ISBN queries (they should remain exact).
        let lower = trimmed.lowercased()
        if lower.contains("isbn:") { return query }

        guard language != .any else { return query }
        guard lower.contains("subject:") else { return query }

        return replacingSubjectOperators(in: trimmed, language: language)
    }

    // MARK: - Subject replacement

    private static func replacingSubjectOperators(in query: String, language: BookImportLanguageOption) -> String {
        // Match `subject:something` or `subject:"multi word"`.
        // We stop at whitespace or ')' to keep parentheses intact.
        let pattern = #"subject:(\"[^\"]+\"|[^\s\)]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return query
        }

        let ns = query as NSString
        let matches = regex.matches(in: query, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return query }

        // Replace from the back to keep ranges stable.
        var out = query
        for m in matches.reversed() {
            guard m.numberOfRanges >= 2 else { continue }

            let fullRange = m.range(at: 0)
            let termRange = m.range(at: 1)

            let rawTermWithMaybeQuotes = ns.substring(with: termRange)
            let rawTerm = stripQuotes(rawTermWithMaybeQuotes)

            let replacement = localizedBroadTerm(for: rawTerm, language: language)
            let safe = quoteIfNeeded(replacement)

            if let swiftRange = Range(fullRange, in: out) {
                out.replaceSubrange(swiftRange, with: safe)
            }
        }

        // Cleanup double spaces introduced by replacements.
        out = out
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return out
    }

    private static func localizedBroadTerm(for subjectTerm: String, language: BookImportLanguageOption) -> String {
        let canon = canonicalKey(subjectTerm)

        // If we have a localized mapping for this term, use it.
        if let localized = localizedSubjectMap[language]?[canon] {
            return localized
        }

        // Otherwise, keeping the term but removing `subject:` often already helps.
        return subjectTerm
    }

    // MARK: - Canonicalization

    private static func canonicalKey(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = folded.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let s = String(scalars)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return s
    }

    private static func stripQuotes(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count >= 2 {
            t.removeFirst()
            t.removeLast()
        }
        return t
    }

    private static func quoteIfNeeded(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return s }

        // Already quoted
        if t.hasPrefix("\"") && t.hasSuffix("\"") { return t }

        // Quote when there are spaces or special chars that would split the term.
        if t.contains(" ") {
            return "\"\(t)\""
        }
        return t
    }

    // MARK: - Localized mapping

    /// Canonical subject term -> localized broad term
    /// Note: canonical keys are diacritic-insensitive and lowercased.
    private static let localizedSubjectMap: [BookImportLanguageOption: [String: String]] = [
        .de: [
            "autobiography": "Autobiografie",
            "biography": "Biografie",
            "science fiction": "Science Fiction",
            "crime": "Krimi",
            "thriller": "Thriller",
            "fantasy": "Fantasy",
            "horror": "Horror",
            "romance": "Liebesroman",
            "psychology": "Psychologie",
            "business": "Wirtschaft",
            "economics": "Ökonomie",
            "history": "Geschichte",
            "self help": "Selbsthilfe",
            "health fitness": "Gesundheit Fitness",
            "travel": "Reise"
        ],
        .fr: [
            "autobiography": "autobiographie",
            "biography": "biographie",
            "science fiction": "science fiction",
            "crime": "policier",
            "thriller": "thriller",
            "fantasy": "fantasy",
            "horror": "horreur",
            "romance": "romance",
            "psychology": "psychologie",
            "business": "commerce",
            "economics": "economie",
            "history": "histoire"
        ],
        .es: [
            "autobiography": "autobiografia",
            "biography": "biografia",
            "science fiction": "ciencia ficcion",
            "crime": "novela negra",
            "thriller": "thriller",
            "fantasy": "fantasia",
            "horror": "terror",
            "romance": "romance",
            "psychology": "psicologia",
            "business": "negocios",
            "economics": "economia",
            "history": "historia"
        ],
        .it: [
            "autobiography": "autobiografia",
            "biography": "biografia",
            "science fiction": "fantascienza",
            "crime": "giallo",
            "thriller": "thriller",
            "fantasy": "fantasy",
            "horror": "horror",
            "romance": "romanzo rosa",
            "psychology": "psicologia",
            "business": "business",
            "economics": "economia",
            "history": "storia"
        ]
    ]
}
