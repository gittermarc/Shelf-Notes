//
//  ReadingSharePayloadParser.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSharePayloadInput: Equatable, Sendable {
    var title: String?
    var text: String?
    var url: URL?

    init(title: String? = nil, text: String? = nil, url: URL? = nil) {
        self.title = title
        self.text = text
        self.url = url
    }
}

nonisolated enum ReadingSharePayloadParserError: Error, Equatable, Sendable {
    case empty
    case unsupportedURL
}

nonisolated enum ReadingSharePayloadParser {
    static func parse(_ input: ReadingSharePayloadInput) throws -> ReadingSharePayload {
        let title = ReadingShareTextNormalizer.normalizedOptional(input.title, maxLength: 240)
        let text = ReadingShareTextNormalizer.normalizedOptional(
            input.text,
            maxLength: ReadingShareTextNormalizer.maxBodyLength
        )

        let explicitURL = input.url
        let embeddedURL = explicitURL == nil ? ReadingShareURLClassifier.firstURL(in: text) : nil
        let url = explicitURL ?? embeddedURL
        let classification = url.flatMap(ReadingShareURLClassifier.classify)

        if input.url != nil, classification == nil {
            throw ReadingSharePayloadParserError.unsupportedURL
        }

        let isbnCandidates = ReadingShareURLClassifier.normalizedISBNs(
            (classification?.isbn13Candidates ?? []) + ReadingShareURLClassifier.isbnCandidates(in: text)
        )

        if let classification, let url {
            return ReadingSharePayload(
                kind: text == nil ? .bookLink : .textWithURL,
                provider: classification.provider,
                title: title,
                text: textWithoutURL(text, url: url),
                url: url,
                canonicalURL: classification.canonicalURL,
                providerItemIdentifier: classification.providerItemIdentifier,
                isbn13Candidates: isbnCandidates
            )
        }

        guard let text else {
            if title != nil {
                return ReadingSharePayload(kind: .text, provider: .other, title: title, text: nil)
            }
            throw ReadingSharePayloadParserError.empty
        }

        return ReadingSharePayload(
            kind: .text,
            provider: .other,
            title: title,
            text: text,
            isbn13Candidates: isbnCandidates
        )
    }

    static func parse(title: String?, text: String?, url: URL?) throws -> ReadingSharePayload {
        try parse(ReadingSharePayloadInput(title: title, text: text, url: url))
    }

    private static func textWithoutURL(_ text: String?, url: URL) -> String? {
        guard let text else { return nil }
        let candidates = [url.absoluteString, url.description]
        var result = text
        for candidate in candidates {
            result = result.replacingOccurrences(of: candidate, with: " ")
        }
        return ReadingShareTextNormalizer.normalizedOptional(
            result,
            maxLength: ReadingShareTextNormalizer.maxBodyLength
        )
    }
}
