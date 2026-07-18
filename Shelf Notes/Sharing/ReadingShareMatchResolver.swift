//
//  ReadingShareMatchResolver.swift
//  Shelf Notes
//

import Foundation

enum ReadingShareMatchConfidence: Equatable {
    case confirmed
    case needsUserConfirmation
}

struct ReadingShareBookMatch: Equatable, Identifiable {
    var bookID: UUID
    var title: String
    var author: String
    var confidence: ReadingShareMatchConfidence
    var reason: String

    var id: UUID { bookID }
}

struct ReadingSharePreparedImport: Equatable {
    var query: String
    var reason: String
}

enum ReadingShareResolution: Equatable {
    case matched(ReadingShareBookMatch)
    case needsConfirmation(ReadingShareBookMatch)
    case needsImport(ReadingSharePreparedImport)
}

enum ReadingShareMatchResolver {
    static func resolve(item: ReadingShareInboxItem, books: [Book]) -> ReadingShareResolution {
        if let match = externalReferenceMatch(item: item, books: books) {
            return .matched(match)
        }

        if let match = isbnMatch(item: item, books: books) {
            return .matched(match)
        }

        if let match = titleCandidate(item: item, books: books) {
            return .needsConfirmation(match)
        }

        return .needsImport(preparedImport(item: item))
    }

    static func preparedImport(item: ReadingShareInboxItem) -> ReadingSharePreparedImport {
        let payload = item.payload
        if let isbn = isbnCandidates(for: payload).first {
            return ReadingSharePreparedImport(query: isbn, reason: "ISBN aus dem Share")
        }

        if let title = payload.title, !title.isEmpty {
            return ReadingSharePreparedImport(query: title, reason: "Titel aus dem Share")
        }

        if let identifier = payload.providerItemIdentifier, !identifier.isEmpty {
            return ReadingSharePreparedImport(query: identifier, reason: "Provider-Referenz aus dem Share")
        }

        if let canonicalURL = payload.canonicalURL, !canonicalURL.isEmpty {
            return ReadingSharePreparedImport(query: canonicalURL, reason: "Unbekannter Buchlink")
        }

        return ReadingSharePreparedImport(query: payload.text ?? "", reason: "Text aus dem Share")
    }

    private static func externalReferenceMatch(
        item: ReadingShareInboxItem,
        books: [Book]
    ) -> ReadingShareBookMatch? {
        let payload = item.payload
        let canonicalURL = normalizedURL(payload.canonicalURL)
        let providerID = normalizedText(payload.providerItemIdentifier)

        let matches = books.filter { book in
            book.externalReferencesSafe.contains { reference in
                guard reference.provider == payload.provider else { return false }
                if let providerID, normalizedText(reference.providerItemIdentifier) == providerID {
                    return true
                }
                if let canonicalURL, normalizedURL(reference.canonicalURL) == canonicalURL {
                    return true
                }
                return false
            }
        }

        guard let book = unique(matches) else { return nil }
        return makeMatch(book: book, confidence: .confirmed, reason: "Bestehende externe Referenz")
    }

    private static func isbnMatch(item: ReadingShareInboxItem, books: [Book]) -> ReadingShareBookMatch? {
        let isbns = Set(isbnCandidates(for: item.payload))
        guard !isbns.isEmpty else { return nil }

        let matches = books.filter { book in
            if let isbn = normalizedISBN(book.isbn13), isbns.contains(isbn) {
                return true
            }
            return book.externalReferencesSafe.contains { reference in
                guard let isbn = normalizedISBN(reference.isbn13) else { return false }
                return isbns.contains(isbn)
            }
        }

        guard let book = unique(matches) else { return nil }
        return makeMatch(book: book, confidence: .confirmed, reason: "ISBN-Treffer")
    }

    private static func titleCandidate(
        item: ReadingShareInboxItem,
        books: [Book]
    ) -> ReadingShareBookMatch? {
        let title = normalizedTitle(item.payload.title)
        guard let title else { return nil }

        let candidates = books.filter { book in
            let bookTitle = normalizedTitle(book.title)
            guard let bookTitle else { return false }
            return bookTitle == title || bookTitle.contains(title) || title.contains(bookTitle)
        }

        guard let book = unique(candidates) else { return nil }
        return makeMatch(book: book, confidence: .needsUserConfirmation, reason: "Unsicherer Titel-Treffer")
    }

    private static func makeMatch(
        book: Book,
        confidence: ReadingShareMatchConfidence,
        reason: String
    ) -> ReadingShareBookMatch {
        ReadingShareBookMatch(
            bookID: book.id,
            title: book.title,
            author: book.author,
            confidence: confidence,
            reason: reason
        )
    }

    private static func unique(_ books: [Book]) -> Book? {
        let uniqueBooks = Dictionary(grouping: books, by: \.id).compactMap { $0.value.first }
        return uniqueBooks.count == 1 ? uniqueBooks[0] : nil
    }

    private static func normalizedURL(_ value: String?) -> String? {
        ReadingShareTextNormalizer.normalizedOptional(value, maxLength: 2_048)?.lowercased()
    }

    private static func normalizedText(_ value: String?) -> String? {
        ReadingShareTextNormalizer.normalizedOptional(value, maxLength: 240)?.lowercased()
    }

    private static func normalizedISBN(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        return digits.count == 13 ? digits : nil
    }

    private static func isbnCandidates(for payload: ReadingSharePayload) -> [String] {
        ReadingShareURLClassifier.normalizedISBNs(
            payload.isbn13Candidates
                + ReadingShareURLClassifier.isbnCandidates(in: payload.text)
                + ReadingShareURLClassifier.isbnCandidates(in: payload.title)
                + ReadingShareURLClassifier.isbnCandidates(in: payload.canonicalURL)
                + ReadingShareURLClassifier.isbnCandidates(in: payload.url?.absoluteString)
        )
    }

    private static func normalizedTitle(_ value: String?) -> String? {
        ReadingShareTextNormalizer.normalizedOptional(value, maxLength: 240)?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
