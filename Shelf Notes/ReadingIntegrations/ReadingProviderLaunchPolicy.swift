//
//  ReadingProviderLaunchPolicy.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingProviderLaunchReference: Equatable, Hashable, Sendable {
    var provider: ReadingProvider
    var providerItemIdentifier: String?
    var canonicalURL: String?

    init(
        provider: ReadingProvider,
        providerItemIdentifier: String? = nil,
        canonicalURL: String? = nil
    ) {
        self.provider = provider
        self.providerItemIdentifier = Self.normalizedText(providerItemIdentifier)
        self.canonicalURL = Self.normalizedText(canonicalURL)
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }
}

nonisolated struct ReadingProviderLaunchGuidance: Equatable, Sendable {
    var provider: ReadingProvider
    var title: String
    var message: String
}

nonisolated enum ReadingProviderLaunchDecision: Equatable, Sendable {
    case open(URL)
    case missingReadingLink(ReadingProviderLaunchGuidance)
    case blocked(String)
    case notAvailable(String)
}

nonisolated enum ReadingProviderLaunchPolicy {
    static func decision(
        provider: ReadingProvider,
        references: [ReadingProviderLaunchReference],
        registry: ReadingIntegrationRegistry = .default
    ) -> ReadingProviderLaunchDecision {
        guard registry.supportsCompanionLaunch(for: provider) else {
            return .notAvailable("Für diese Lesequelle gibt es in diesem Stand keinen Begleit-Start.")
        }

        let providerReferences = references.filter { $0.provider == provider }
        let urlStrings = providerReferences.compactMap(\.canonicalURL)

        guard urlStrings.isEmpty == false else {
            return .missingReadingLink(guidance(for: provider))
        }

        for urlString in urlStrings {
            if let url = validatedReadingURL(rawString: urlString, provider: provider) {
                return .open(url)
            }
        }

        return .blocked("Der gespeicherte Leselink ist kein unterstützter HTTPS- oder Universal-Link für diese Quelle.")
    }

    static func validatedReadingURL(rawString: String?, provider: ReadingProvider) -> URL? {
        guard let rawString = rawString?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawString.isEmpty == false,
              let url = URL(string: rawString) else {
            return nil
        }
        return validatedReadingURL(url, provider: provider)
    }

    static func validatedReadingURL(_ url: URL, provider: ReadingProvider) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard components.scheme?.lowercased() == "https" else { return nil }
        guard let host = components.host?.lowercased(), isPublicHost(host) else { return nil }

        switch provider {
        case .appleBooks:
            return isAppleBooksHost(host) ? url : nil
        case .kindle:
            return isKindleHost(host, path: components.path) ? url : nil
        case .googleBooks:
            return isGoogleBooksHost(host, path: components.path) ? url : nil
        case .other:
            return url
        case .localFile, .none:
            return nil
        }
    }

    static func guidance(for provider: ReadingProvider) -> ReadingProviderLaunchGuidance {
        switch provider {
        case .appleBooks:
            return ReadingProviderLaunchGuidance(
                provider: provider,
                title: "Kein Apple-Books-Link gespeichert",
                message: "Der Timer läuft. Öffne Apple Books manuell, lies weiter und kehre danach zu Shelf Notes zurück, um die Session zu stoppen."
            )
        case .kindle:
            return ReadingProviderLaunchGuidance(
                provider: provider,
                title: "Kein Kindle-Link gespeichert",
                message: "Der Timer läuft. Öffne Kindle manuell, lies weiter und kehre danach zu Shelf Notes zurück, um die Session zu stoppen."
            )
        case .other:
            return ReadingProviderLaunchGuidance(
                provider: provider,
                title: "Kein Leselink gespeichert",
                message: "Der Timer läuft. Öffne deine Reader-App manuell, lies weiter und kehre danach zu Shelf Notes zurück, um die Session zu stoppen."
            )
        default:
            return ReadingProviderLaunchGuidance(
                provider: provider,
                title: "Kein Begleit-Start verfügbar",
                message: "Für diese Lesequelle gibt es in diesem Stand keinen automatischen Start in eine externe Reader-App."
            )
        }
    }

    private static func isAppleBooksHost(_ host: String) -> Bool {
        host == "books.apple.com" || host == "itunes.apple.com"
    }

    private static func isKindleHost(_ host: String, path: String) -> Bool {
        if allowedKindleReaderHosts.contains(host) {
            return true
        }

        guard isAmazonHost(host) else { return false }
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

    private static func isAmazonHost(_ host: String) -> Bool {
        allowedAmazonHosts.contains(host)
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

    private static func isPublicHost(_ host: String) -> Bool {
        guard host.isEmpty == false else { return false }
        if host == "localhost" || host.hasSuffix(".localhost") { return false }
        if host.hasPrefix("127.") || host.hasPrefix("10.") || host.hasPrefix("0.") { return false }
        if host.hasPrefix("192.168.") { return false }
        if host.hasPrefix("169.254.") { return false }
        if host.range(of: #"^172\.(1[6-9]|2[0-9]|3[0-1])\."#, options: .regularExpression) != nil {
            return false
        }
        return true
    }
}