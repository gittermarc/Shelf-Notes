//
//  BookImportQueryBuilder.swift
//  Shelf Notes
//
//  Encapsulates Google Books query construction (normalization, scope, category operators)
//  and query options mapping (language/sort/filter).
//

import Foundation

struct BookImportQueryBuilder {
    var scope: BookImportSearchScope
    var category: String

    init(scope: BookImportSearchScope, category: String) {
        self.scope = scope
        self.category = category
    }

    /// Normalizes the raw query. If it looks like an ISBN (10 or 13 digits), it becomes an `isbn:` query.
    static func normalizedQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 || digits.count == 13 {
            return "isbn:\(digits)"
        }
        return trimmed
    }

    /// True when the query contains Google Books advanced operators (subject:, intitle:, etc.).
    /// Used to avoid rewriting user-provided operator queries.
    static func containsAdvancedOperators(_ query: String) -> Bool {
        let lower = query.lowercased()
        return lower.contains("isbn:")
            || lower.contains("intitle:")
            || lower.contains("inauthor:")
            || lower.contains("subject:")
            || lower.contains("inpublisher:")
            || lower.contains("lccn:")
            || lower.contains("oclc:")
    }

    /// Builds a `subject:` query from a free-text term (quotes are added only when needed).
    static func makeSubjectQuery(fromFreeText input: String) -> String {
        let cleaned = input
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        return "subject:\(Self.quoteIfNeeded(cleaned))"
    }


    /// Builds the effective query string using scope (intitle/inauthor) and a robust category fragment.
    ///
    /// Notes:
    /// - If the user already uses advanced operators, we avoid rewriting and only append the category when safe.
    /// - We never append category for `isbn:` queries (Google ignores / behaves inconsistently there).
    /// - Category fragments are expanded via `BookImportCategoryNormalizer` to prevent "0 results" traps.
    func buildEffectiveQuery(from base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lower = trimmed.lowercased()
        let isISBNQuery = lower.hasPrefix("isbn:")
        let usesOperators = Self.containsAdvancedOperators(trimmed)

        var q = trimmed

        if !usesOperators && !isISBNQuery {
            switch scope {
            case .any:
                break
            case .title:
                q = "intitle:\(Self.quoteIfNeeded(trimmed))"
            case .author:
                q = "inauthor:\(Self.quoteIfNeeded(trimmed))"
            }
        }

        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty && !isISBNQuery {
            if let fragment = BookImportCategoryNormalizer.queryFragment(forSelectedCategory: cat), !fragment.isEmpty {
                q += " \(fragment)"
            } else {
                // Defensive fallback.
                q += " subject:\(Self.quoteIfNeeded(cat))"
            }
        }

        return q
    }

    func makeQueryOptions(
        language: BookImportLanguageOption,
        sortOption: BookImportSortOption,
        apiFilter: GoogleBooksFilter
    ) -> GoogleBooksQueryOptions {
        var opt = GoogleBooksQueryOptions.default
        opt.langRestrict = language.apiValue
        opt.orderBy = sortOption.apiOrderBy
        opt.filter = apiFilter
        opt.projection = .lite
        return opt
    }

    // MARK: - Helpers

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
}
