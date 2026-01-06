//
//  GoogleBooksClient.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import Foundation

struct GoogleBooksDebugInfo {
    let requestURL: String
    let httpStatus: Int?
    let responseBytes: Int
    let errorBodySnippet: String?
}

struct GoogleBooksSearchResult {
    let totalItems: Int
    let startIndex: Int
    let maxResults: Int
    let volumes: [GoogleBookVolume]
    let debug: GoogleBooksDebugInfo
}

// MARK: - Query Options

enum GoogleBooksOrderBy: String, CaseIterable, Identifiable {
    case relevance
    case newest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relevance: return "Relevanz"
        case .newest: return "Neueste"
        }
    }
}

enum GoogleBooksFilter: String, CaseIterable, Identifiable {
    /// Don't send the filter param at all
    case none = ""

    case partial
    case full

    // Google Books API uses hyphenated values
    case freeEbooks = "free-ebooks"
    case paidEbooks = "paid-ebooks"
    case ebooks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Alle"
        case .partial: return "Vorschau (Partial)"
        case .full: return "Vollansicht (Full)"
        case .freeEbooks: return "Kostenlose E-Books"
        case .paidEbooks: return "Kaufbare E-Books"
        case .ebooks: return "Alle E-Books"
        }
    }

    var shouldSendToAPI: Bool { self != .none }
}

enum GoogleBooksProjection: String, CaseIterable, Identifiable {
    case lite
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lite: return "Lite"
        case .full: return "Full"
        }
    }
}

struct GoogleBooksQueryOptions {
    var langRestrict: String? = nil
    var orderBy: GoogleBooksOrderBy = .relevance
    var filter: GoogleBooksFilter = .none
    var projection: GoogleBooksProjection = .lite

    static let `default` = GoogleBooksQueryOptions()
}

// MARK: - Error

enum GoogleBooksError: LocalizedError {
    case invalidURL
    case badStatus(Int, String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige Anfrage-URL."
        case .badStatus(let code, let snippet):
            if let snippet, !snippet.isEmpty {
                return "Google Books API Fehler (HTTP \(code)): \(snippet)"
            }
            return "Google Books API Fehler (HTTP \(code))."
        case .emptyResponse:
            return "Keine Daten von Google Books erhalten."
        }
    }
}

// MARK: - Client

final class GoogleBooksClient {
    static let shared = GoogleBooksClient()

    private let session: URLSession
    private let apiKey: String?

    private init(session: URLSession = .shared) {
        self.session = session
        self.apiKey = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns volumes plus debug info (URL, status, bytes, optional error snippet)
    ///
    /// Notes:
    /// - Google Books allows maxResults up to 40 per request.
    /// - For more than 40 results, use pagination via `startIndex`.
    func searchVolumesWithDebug(
        query: String,
        startIndex: Int = 0,
        maxResults: Int = 40,
        options: GoogleBooksQueryOptions = .default
    ) async throws -> GoogleBooksSearchResult {

        var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        let clampedMax = min(max(maxResults, 1), 40)
        let clampedStart = max(startIndex, 0)

        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "startIndex", value: String(clampedStart)),
            URLQueryItem(name: "maxResults", value: String(clampedMax)),
            URLQueryItem(name: "printType", value: "books"),

            // Explicit settings help with reproducibility / debugging
            URLQueryItem(name: "orderBy", value: options.orderBy.rawValue)
        ]

        if let lang = options.langRestrict?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lang.isEmpty {
            items.append(URLQueryItem(name: "langRestrict", value: lang))
        }

        if options.filter.shouldSendToAPI {
            items.append(URLQueryItem(name: "filter", value: options.filter.rawValue))
        }

        if options.projection != .lite {
            items.append(URLQueryItem(name: "projection", value: options.projection.rawValue))
        }

        // Key is optional for testing; if present we send it.
        if let apiKey, !apiKey.isEmpty {
            items.append(URLQueryItem(name: "key", value: apiKey))
        }

        comps?.queryItems = items
        guard let url = comps?.url else { throw GoogleBooksError.invalidURL }

        let (data, response) = try await session.data(from: url)
        let http = response as? HTTPURLResponse

        let debugBase = GoogleBooksDebugInfo(
            requestURL: url.absoluteString,
            httpStatus: http?.statusCode,
            responseBytes: data.count,
            errorBodySnippet: nil
        )

        guard let http else {
            throw GoogleBooksError.emptyResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(220)
            throw GoogleBooksError.badStatus(http.statusCode, snippet.map(String.init))
        }

        let decoded = try JSONDecoder().decode(GoogleBooksVolumesResponse.self, from: data)
        let volumes = decoded.items ?? []
        let total = decoded.totalItems ?? volumes.count

        let debug = GoogleBooksDebugInfo(
            requestURL: debugBase.requestURL,
            httpStatus: debugBase.httpStatus,
            responseBytes: debugBase.responseBytes,
            errorBodySnippet: nil
        )

        return GoogleBooksSearchResult(
            totalItems: total,
            startIndex: clampedStart,
            maxResults: clampedMax,
            volumes: volumes,
            debug: debug
        )
    }
}
