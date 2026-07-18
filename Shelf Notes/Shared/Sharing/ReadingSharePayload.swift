//
//  ReadingSharePayload.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSharePayload: Codable, Equatable, Hashable, Sendable {
    var kind: ReadingSharePayloadKind
    var provider: ReadingProvider
    var title: String?
    var text: String?
    var url: URL?
    var canonicalURL: String?
    var providerItemIdentifier: String?
    var isbn13Candidates: [String]

    init(
        kind: ReadingSharePayloadKind,
        provider: ReadingProvider = .other,
        title: String? = nil,
        text: String? = nil,
        url: URL? = nil,
        canonicalURL: String? = nil,
        providerItemIdentifier: String? = nil,
        isbn13Candidates: [String] = []
    ) {
        self.kind = kind
        self.provider = provider
        self.title = ReadingShareTextNormalizer.normalizedOptional(title, maxLength: 240)
        self.text = ReadingShareTextNormalizer.normalizedOptional(text, maxLength: ReadingShareTextNormalizer.maxBodyLength)
        self.url = url
        self.canonicalURL = ReadingShareTextNormalizer.normalizedOptional(canonicalURL, maxLength: 2_048)
        self.providerItemIdentifier = ReadingShareTextNormalizer.normalizedOptional(providerItemIdentifier, maxLength: 240)
        self.isbn13Candidates = Self.normalizedISBNs(isbn13Candidates)
    }

    var hasText: Bool {
        text?.isEmpty == false
    }

    var hasURL: Bool {
        canonicalURL?.isEmpty == false || url != nil
    }

    var stableComponents: [String] {
        [
            kind.rawValue,
            provider.rawValue,
            canonicalURL ?? url?.absoluteString ?? "",
            providerItemIdentifier ?? "",
            title ?? "",
            text ?? "",
            isbn13Candidates.joined(separator: ",")
        ]
    }

    private static func normalizedISBNs(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let digits = value.filter(\.isNumber)
            guard digits.count == 13, seen.insert(digits).inserted else { return nil }
            return digits
        }
    }
}
