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
    let volumes: [GoogleBookVolume]
    let debug: GoogleBooksDebugInfo
}

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
    func searchVolumesWithDebug(query: String, maxResults: Int = 20) async throws -> GoogleBooksSearchResult {
        var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        let clamped = min(maxResults, 40)

        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(clamped)),
            URLQueryItem(name: "printType", value: "books")
        ]

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

        let debug = GoogleBooksDebugInfo(
            requestURL: debugBase.requestURL,
            httpStatus: debugBase.httpStatus,
            responseBytes: debugBase.responseBytes,
            errorBodySnippet: nil
        )

        return GoogleBooksSearchResult(volumes: volumes, debug: debug)
    }
}
