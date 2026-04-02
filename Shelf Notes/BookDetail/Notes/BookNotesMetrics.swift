import Foundation

struct BookNotesMetrics: Equatable {
    let text: String
    let trimmedText: String
    let wordCount: Int
    let paragraphCount: Int
    let characterCount: Int
    let previewText: String

    init(text: String) {
        self.text = text
        self.trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.wordCount = BookNotesMetrics.countWords(in: trimmedText)
        self.paragraphCount = BookNotesMetrics.countParagraphs(in: trimmedText)
        self.characterCount = trimmedText.count
        self.previewText = BookNotesMetrics.makePreview(from: trimmedText)
    }

    var isEmpty: Bool {
        trimmedText.isEmpty
    }

    var hasContent: Bool {
        !isEmpty
    }

    var summaryLine: String {
        guard hasContent else { return "Noch keine Notiz" }

        var parts: [String] = []
        parts.append(BookNotesMetrics.localizedCount(wordCount, singular: "Wort", plural: "Wörter"))
        parts.append(BookNotesMetrics.localizedCount(paragraphCount, singular: "Absatz", plural: "Absätze"))
        return parts.joined(separator: " · ")
    }

    var detailLine: String {
        guard hasContent else { return "Platz für Gedanken, Zitate und kleine Aha-Momente." }

        var parts: [String] = []
        parts.append(BookNotesMetrics.localizedCount(characterCount, singular: "Zeichen", plural: "Zeichen"))
        parts.append(BookNotesMetrics.localizedCount(paragraphCount, singular: "Absatz", plural: "Absätze"))
        return parts.joined(separator: " · ")
    }

    private static func countWords(in text: String) -> Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    private static func countParagraphs(in text: String) -> Int {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.count
    }

    private static func makePreview(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        let normalizedLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let joined = normalizedLines.joined(separator: " ")
        guard joined.count > 180 else { return joined }

        let index = joined.index(joined.startIndex, offsetBy: 180)
        let prefix = joined[..<index].trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix + "…"
    }

    private static func localizedCount(_ value: Int, singular: String, plural: String) -> String {
        let label = value == 1 ? singular : plural
        return "\(value) \(label)"
    }
}
