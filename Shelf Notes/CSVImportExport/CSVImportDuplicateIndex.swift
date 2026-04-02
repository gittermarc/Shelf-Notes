import Foundation

nonisolated struct CSVImportDuplicateIndex: Sendable {
    private(set) var normalizedISBNs: Set<String>
    private(set) var volumeIDs: Set<String>
    private(set) var normalizedTitles: Set<String>

    init(
        normalizedISBNs: Set<String> = [],
        volumeIDs: Set<String> = [],
        normalizedTitles: Set<String> = []
    ) {
        self.normalizedISBNs = normalizedISBNs
        self.volumeIDs = volumeIDs
        self.normalizedTitles = normalizedTitles
    }

    init(books: [Book]) {
        self.normalizedISBNs = Set(
            books
                .compactMap { $0.isbn13 }
                .map(Self.normalizedISBN)
                .filter { !$0.isEmpty }
        )
        self.volumeIDs = Set(
            books
                .compactMap { $0.googleVolumeID }
                .map(Self.normalizedVolumeID)
                .filter { !$0.isEmpty }
        )
        self.normalizedTitles = Set(
            books
                .map { Self.normalizedTitle($0.title) }
                .filter { !$0.isEmpty }
        )
    }

    func contains(isbn: String) -> Bool {
        let normalized = Self.normalizedISBN(isbn)
        guard !normalized.isEmpty else { return false }
        return normalizedISBNs.contains(normalized)
    }

    func contains(volumeID: String?) -> Bool {
        let normalized = Self.normalizedVolumeID(volumeID)
        guard !normalized.isEmpty else { return false }
        return volumeIDs.contains(normalized)
    }

    func contains(title: String) -> Bool {
        let normalized = Self.normalizedTitle(title)
        guard !normalized.isEmpty else { return false }
        return normalizedTitles.contains(normalized)
    }

    mutating func register(book: Book) {
        register(volumeID: book.googleVolumeID, title: book.title, isbn: book.isbn13)
    }

    mutating func register(volumeID: String?, title: String, isbn: String?) {
        let normalizedVolumeID = Self.normalizedVolumeID(volumeID)
        if !normalizedVolumeID.isEmpty {
            volumeIDs.insert(normalizedVolumeID)
        }

        let normalizedTitle = Self.normalizedTitle(title)
        if !normalizedTitle.isEmpty {
            normalizedTitles.insert(normalizedTitle)
        }

        let normalizedISBN = Self.normalizedISBN(isbn)
        if !normalizedISBN.isEmpty {
            normalizedISBNs.insert(normalizedISBN)
        }
    }

    static func normalizedTitle(_ rawTitle: String) -> String {
        rawTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func normalizedISBN(_ rawISBN: String?) -> String {
        (rawISBN ?? "").filter(\.isNumber)
    }

    static func normalizedVolumeID(_ rawVolumeID: String?) -> String {
        (rawVolumeID ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
