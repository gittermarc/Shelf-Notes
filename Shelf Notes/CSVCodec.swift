//
//  CSVCodec.swift
//  Shelf Notes
//
//  CSV import/export helpers (ISBN + Titel).
//
//  Notes:
//  - Accepts comma OR semicolon delimiter (auto-detect on first non-empty line).
//  - Supports quoted fields ("...") and escaped quotes ("").
//  - Tries to detect a header row.
//

import Foundation

struct CSVRow: Equatable {
    var title: String
    var isbn: String

    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedISBN: String {
        isbn.filter(\.isNumber)
    }

    /// At least one of (title, isbn) must be present.
    var hasRequiredField: Bool {
        !normalizedTitle.isEmpty || !normalizedISBN.isEmpty
    }
}

enum CSVCodecError: Error, LocalizedError {
    case unreadableData

    var errorDescription: String? {
        switch self {
        case .unreadableData:
            return "Die CSV-Datei konnte nicht gelesen werden."
        }
    }
}

enum CSVCodec {

    /// Decodes CSV into canonical rows.
    /// - Returns: rows + used delimiter + whether a header was detected.
    static func decode(_ data: Data) throws -> (rows: [CSVRow], delimiter: Character, hadHeader: Bool) {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CSVCodecError.unreadableData
        }

        // Normalize line endings.
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")

        // Determine delimiter (comma vs semicolon) based on first non-empty line.
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .first ?? ""

        let commaCount = firstLine.filter { $0 == "," }.count
        let semiCount = firstLine.filter { $0 == ";" }.count
        let delimiter: Character = (semiCount > commaCount) ? ";" : ","

        let table = parseCSV(text, delimiter: delimiter)
            .map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { row in
                // Drop totally empty rows.
                row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            }

        guard !table.isEmpty else {
            return ([], delimiter, false)
        }

        // Header detection.
        let header = table[0].map { $0.lowercased() }
        let titleNames: Set<String> = ["title", "titel", "booktitle", "book_title", "name"]
        let isbnNames: Set<String>  = ["isbn", "isbn13", "isbn_13", "ean", "ean13", "ean_13"]

        func idx(for names: Set<String>) -> Int? {
            for (i, h) in header.enumerated() {
                let cleaned = h
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "_")
                if names.contains(cleaned) { return i }
            }
            return nil
        }

        let titleIdx = idx(for: titleNames)
        let isbnIdx = idx(for: isbnNames)
        let hadHeader = (titleIdx != nil) || (isbnIdx != nil)

        let bodyRows = hadHeader ? Array(table.dropFirst()) : table

        var out: [CSVRow] = []
        out.reserveCapacity(bodyRows.count)

        for r in bodyRows {
            let title: String
            let isbn: String

            if hadHeader {
                title = value(at: titleIdx, in: r) ?? ""
                isbn = value(at: isbnIdx, in: r) ?? ""
            } else {
                // No header: assume first col = title, second col = isbn.
                title = (r.count > 0) ? r[0] : ""
                isbn = (r.count > 1) ? r[1] : ""
            }

            out.append(CSVRow(title: title, isbn: isbn))
        }

        return (out, delimiter, hadHeader)
    }

    static func encode(_ rows: [CSVRow], delimiter: Character = ",", includeHeader: Bool = true) -> Data {
        var lines: [String] = []
        if includeHeader {
            lines.append("title\(delimiter)isbn13")
        }

        for r in rows {
            let title = escapeField(r.title, delimiter: delimiter)
            let isbn = escapeField(r.isbn, delimiter: delimiter)
            lines.append("\(title)\(delimiter)\(isbn)")
        }

        let text = lines.joined(separator: "\n") + "\n"
        return Data(text.utf8)
    }

    // MARK: - Internal

    private static func value(at idx: Int?, in row: [String]) -> String? {
        guard let idx, idx >= 0, idx < row.count else { return nil }
        return row[idx]
    }

    private static func escapeField(_ value: String, delimiter: Character) -> String {
        let needsQuote = value.contains(delimiter) || value.contains("\"") || value.contains("\n")
        if !needsQuote { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + escaped + "\""
    }

    /// Character-based CSV parser supporting quoted fields.
    private static func parseCSV(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""

        var inQuotes = false
        var i = text.startIndex

        func flushField() {
            row.append(field)
            field = ""
        }

        func flushRow() {
            if !field.isEmpty || !row.isEmpty {
                flushField()
                rows.append(row)
            }
            row = []
            field = ""
        }

        while i < text.endIndex {
            let ch = text[i]

            if inQuotes {
                if ch == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == delimiter {
                    flushField()
                } else if ch == "\n" {
                    flushRow()
                } else {
                    field.append(ch)
                }
            }

            i = text.index(after: i)
        }

        if !field.isEmpty || !row.isEmpty {
            flushRow()
        }

        return rows
    }
}
