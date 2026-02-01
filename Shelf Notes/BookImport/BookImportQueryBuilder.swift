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

    /// Builds the effective query string using scope (intitle/inauthor) and category (subject:).
    ///
    /// Notes:
    /// - If the user already uses advanced operators, we avoid rewriting and only append the category when safe.
    /// - We never append category for `isbn:` queries (Google ignores / behaves inconsistently there).
    func buildEffectiveQuery(from base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lower = trimmed.lowercased()
        let isISBNQuery = lower.hasPrefix("isbn:")
        let usesOperators = lower.contains("isbn:") || lower.contains("intitle:") || lower.contains("inauthor:") || lower.contains("subject:")

        var q = trimmed

        if !usesOperators && !isISBNQuery {
            switch scope {
            case .any:
                break
            case .title:
                q = "intitle:\(quoteIfNeeded(trimmed))"
            case .author:
                q = "inauthor:\(quoteIfNeeded(trimmed))"
            }
        }

        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty && !isISBNQuery {
            q += " subject:\(quoteIfNeeded(cat))"
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

    private func quoteIfNeeded(_ value: String) -> String {
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
