//
//  ReadingShareURLClassifier.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingShareURLClassification: Equatable, Hashable, Sendable {
    var provider: ReadingProvider
    var canonicalURL: String
    var providerItemIdentifier: String?
    var isbn13Candidates: [String]

    init(
        provider: ReadingProvider,
        canonicalURL: String,
        providerItemIdentifier: String? = nil,
        isbn13Candidates: [String] = []
    ) {
        self.provider = provider
        self.canonicalURL = canonicalURL
        self.providerItemIdentifier = ReadingShareTextNormalizer.normalizedOptional(providerItemIdentifier, maxLength: 240)
        self.isbn13Candidates = ReadingShareURLClassifier.normalizedISBNs(isbn13Candidates)
    }
}

nonisolated enum ReadingShareURLClassifier {
    static func classify(_ url: URL) -> ReadingShareURLClassification? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard components.scheme?.lowercased() == "https" else { return nil }
        guard let host = components.host?.lowercased(), isPublicHost(host) else { return nil }

        let canonicalURL = canonicalURL(from: components, fallback: url)
        let isbnCandidates = isbnCandidates(from: components)

        if isAppleBooksHost(host) {
            return ReadingShareURLClassification(
                provider: .appleBooks,
                canonicalURL: canonicalURL,
                providerItemIdentifier: appleBooksIdentifier(from: components),
                isbn13Candidates: isbnCandidates
            )
        }

        if isKindleHost(host, path: components.path) {
            return ReadingShareURLClassification(
                provider: .kindle,
                canonicalURL: canonicalURL,
                providerItemIdentifier: kindleIdentifier(from: components),
                isbn13Candidates: isbnCandidates
            )
        }

        if isGoogleBooksHost(host, path: components.path) {
            return ReadingShareURLClassification(
                provider: .googleBooks,
                canonicalURL: canonicalURL,
                providerItemIdentifier: googleBooksIdentifier(from: components),
                isbn13Candidates: isbnCandidates
            )
        }

        return ReadingShareURLClassification(
            provider: .other,
            canonicalURL: canonicalURL,
            providerItemIdentifier: nil,
            isbn13Candidates: isbnCandidates
        )
    }

    static func classify(rawString: String?) -> ReadingShareURLClassification? {
        guard let value = ReadingShareTextNormalizer.normalizedOptional(rawString, maxLength: 2_048),
              let url = URL(string: value) else {
            return nil
        }
        return classify(url)
    }

    static func firstURL(in text: String?) -> URL? {
        guard let text else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let pattern = #"https://[^\s<>\"]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        return regex
            .matches(in: text, options: [], range: range)
            .compactMap { match -> URL? in
                guard let swiftRange = Range(match.range, in: text) else { return nil }
                return URL(string: String(text[swiftRange]).trimmingCharacters(in: .punctuationCharacters))
            }
            .first { classify($0) != nil }
    }

    static func normalizedISBNs(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let digits = value.filter(\.isNumber)
            guard digits.count == 13, seen.insert(digits).inserted else { return nil }
            return digits
        }
    }

    static func isbnCandidates(in text: String?) -> [String] {
        guard let text else { return [] }
        let pattern = #"(?:97[89][\-\s]?(?:\d[\-\s]?){9}\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return normalizedISBNs(matches.compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange])
        })
    }

    private static func canonicalURL(from components: URLComponents, fallback: URL) -> String {
        var normalized = components
        normalized.scheme = components.scheme?.lowercased()
        normalized.host = components.host?.lowercased()
        normalized.fragment = nil
        return normalized.url?.absoluteString ?? fallback.absoluteString
    }

    private static func isbnCandidates(from components: URLComponents) -> [String] {
        let queryValues = components.queryItems?.compactMap(\.value).joined(separator: " ") ?? ""
        return isbnCandidates(in: components.path + " " + queryValues)
    }

    private static func appleBooksIdentifier(from components: URLComponents) -> String? {
        let pathComponents = components.path.split(separator: "/").map(String.init)
        return pathComponents.last { component in
            component.hasPrefix("id") && component.dropFirst(2).allSatisfy(\.isNumber)
        }
    }

    private static func kindleIdentifier(from components: URLComponents) -> String? {
        let pathComponents = components.path.split(separator: "/").map(String.init)
        for marker in ["dp", "product"] {
            if let index = pathComponents.firstIndex(of: marker), pathComponents.indices.contains(index + 1) {
                return pathComponents[index + 1]
            }
        }
        return components.queryItems?.first { $0.name.lowercased() == "asin" }?.value
    }

    private static func googleBooksIdentifier(from components: URLComponents) -> String? {
        if let id = components.queryItems?.first(where: { $0.name.lowercased() == "id" })?.value {
            return id
        }
        let pathComponents = components.path.split(separator: "/").map(String.init)
        if let index = pathComponents.firstIndex(of: "books"), pathComponents.indices.contains(index + 1) {
            return pathComponents[index + 1]
        }
        return nil
    }

    private static func isAppleBooksHost(_ host: String) -> Bool {
        host == "books.apple.com" || host == "itunes.apple.com"
    }

    private static func isKindleHost(_ host: String, path: String) -> Bool {
        if allowedKindleReaderHosts.contains(host) {
            return true
        }

        guard allowedAmazonHosts.contains(host) else { return false }
        let normalizedPath = path.lowercased()
        return normalizedPath.hasPrefix("/dp/")
            || normalizedPath.hasPrefix("/gp/product/")
            || normalizedPath.hasPrefix("/kindle-dbs/product/")
            || normalizedPath.hasPrefix("/ebooks/")
    }

    private static func isGoogleBooksHost(_ host: String, path: String) -> Bool {
        if host == "books.google.com" {
            return true
        }
        return host == "play.google.com" && path.lowercased().hasPrefix("/store/books")
    }

    private static func isPublicHost(_ host: String) -> Bool {
        guard host.isEmpty == false else { return false }
        if host == "localhost" || host.hasSuffix(".localhost") { return false }
        if host.hasPrefix("127.") || host.hasPrefix("10.") || host.hasPrefix("0.") { return false }
        if host.hasPrefix("192.168.") || host.hasPrefix("169.254.") { return false }
        if host.range(of: #"^172\.(1[6-9]|2[0-9]|3[0-1])\."#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    private static let allowedKindleReaderHosts: Set<String> = [
        "read.amazon.com",
        "read.amazon.co.uk",
        "read.amazon.de",
        "read.amazon.fr",
        "read.amazon.it",
        "read.amazon.es",
        "read.amazon.ca",
        "read.amazon.com.au",
        "read.amazon.co.jp",
        "read.amazon.nl",
        "read.amazon.se",
        "read.amazon.pl",
        "read.amazon.in",
        "read.amazon.com.br",
        "read.amazon.com.mx"
    ]

    private static let allowedAmazonHosts: Set<String> = [
        "amazon.com",
        "www.amazon.com",
        "amazon.co.uk",
        "www.amazon.co.uk",
        "amazon.de",
        "www.amazon.de",
        "amazon.fr",
        "www.amazon.fr",
        "amazon.it",
        "www.amazon.it",
        "amazon.es",
        "www.amazon.es",
        "amazon.ca",
        "www.amazon.ca",
        "amazon.com.au",
        "www.amazon.com.au",
        "amazon.co.jp",
        "www.amazon.co.jp",
        "amazon.nl",
        "www.amazon.nl",
        "amazon.se",
        "www.amazon.se",
        "amazon.pl",
        "www.amazon.pl",
        "amazon.in",
        "www.amazon.in",
        "amazon.com.br",
        "www.amazon.com.br",
        "amazon.com.mx",
        "www.amazon.com.mx"
    ]
}
