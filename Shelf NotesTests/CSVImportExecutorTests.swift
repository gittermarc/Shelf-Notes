import Foundation
import Testing
@testable import Shelf_Notes

struct CSVImportExecutorTests {

    @Test @MainActor func invalidRowsIncreaseInvalidCount() async {
        let executor = makeExecutor(searchResults: [:])
        var progressValues: [Double] = []

        let report = await executor.executeImport(
            rows: [CSVRow(title: "   ", isbn: "")],
            searchMode: .auto,
            importStatus: .toRead,
            duplicateIndex: CSVImportDuplicateIndex(),
            progress: { progressValues.append($0) }
        )

        #expect(report.totalRows == 1)
        #expect(report.invalidRows == 1)
        #expect(report.validRows == 0)
        #expect(report.imported == 0)
        #expect(progressValues.last == 1)
    }

    @Test @MainActor func notFoundRowsIncreaseNotFoundCount() async {
        let executor = makeExecutor(searchResults: [
            "intitle:\"Unknown Book\"": []
        ])

        let report = await executor.executeImport(
            rows: [CSVRow(title: "Unknown Book", isbn: "")],
            searchMode: .title,
            importStatus: .toRead,
            duplicateIndex: CSVImportDuplicateIndex(),
            progress: { _ in }
        )

        #expect(report.totalRows == 1)
        #expect(report.notFound == 1)
        #expect(report.imported == 0)
        #expect(report.validRows == 1)
    }

    @Test @MainActor func duplicateISBNRowsAreSkippedBeforeSearch() async {
        var executedQueries: [String] = []
        let executor = makeExecutor(
            searchResults: [:],
            executedQueries: { executedQueries.append($0) }
        )

        let report = await executor.executeImport(
            rows: [CSVRow(title: "Dune", isbn: "9780441172719")],
            searchMode: .auto,
            importStatus: .toRead,
            duplicateIndex: CSVImportDuplicateIndex(normalizedISBNs: ["9780441172719"]),
            progress: { _ in }
        )

        #expect(report.duplicatesSkipped == 1)
        #expect(report.imported == 0)
        #expect(executedQueries.isEmpty)
    }

    @Test @MainActor func reportCountsImportedRowsAndBackfillCalls() async {
        let volume = makeVolume(id: "vol-1", title: "The Hobbit", isbn13: "9780261103344")
        var savedBooks: [Book] = []
        var backfilledTitles: [String] = []

        let executor = CSVImportExecutor(
            searchVolumes: { query in
                if query == "isbn:9780261103344" {
                    return [volume]
                }
                return []
            },
            saveBook: { savedBooks.append($0) },
            backfillThumbnail: { book in
                backfilledTitles.append(book.title)
            }
        )

        let report = await executor.executeImport(
            rows: [CSVRow(title: "The Hobbit", isbn: "9780261103344")],
            searchMode: .auto,
            importStatus: .finished,
            duplicateIndex: CSVImportDuplicateIndex(),
            progress: { _ in }
        )

        #expect(report.imported == 1)
        #expect(report.errors == 0)
        #expect(savedBooks.count == 1)
        #expect(savedBooks.first?.status == .finished)
        #expect(backfilledTitles == ["The Hobbit"])
    }

    @Test @MainActor func isbnSearchPrefersExactVolumeMatch() async {
        let wrong = makeVolume(id: "vol-wrong", title: "The Hobbit", isbn13: "1111111111111")
        let exact = makeVolume(id: "vol-exact", title: "The Hobbit", isbn13: "9780261103344")
        var savedBooks: [Book] = []

        let executor = CSVImportExecutor(
            searchVolumes: { query in
                #expect(query == "isbn:9780261103344")
                return [wrong, exact]
            },
            saveBook: { savedBooks.append($0) },
            backfillThumbnail: { _ in }
        )

        let report = await executor.executeImport(
            rows: [CSVRow(title: "The Hobbit", isbn: "9780261103344")],
            searchMode: .isbn,
            importStatus: .toRead,
            duplicateIndex: CSVImportDuplicateIndex(),
            progress: { _ in }
        )

        #expect(report.imported == 1)
        #expect(savedBooks.first?.googleVolumeID == "vol-exact")
    }

    @MainActor
    private func makeExecutor(
        searchResults: [String: [GoogleBookVolume]],
        executedQueries: ((String) -> Void)? = nil
    ) -> CSVImportExecutor {
        CSVImportExecutor(
            searchVolumes: { query in
                executedQueries?(query)
                return searchResults[query] ?? []
            },
            saveBook: { _ in },
            backfillThumbnail: { _ in }
        )
    }

    private func makeVolume(id: String, title: String, isbn13: String?) -> GoogleBookVolume {
        GoogleBookVolume(
            id: id,
            volumeInfo: VolumeInfo(
                title: title,
                subtitle: nil,
                authors: ["J. R. R. Tolkien"],
                publisher: nil,
                publishedDate: nil,
                description: nil,
                pageCount: nil,
                categories: nil,
                mainCategory: nil,
                language: nil,
                industryIdentifiers: isbn13.map {
                    [IndustryIdentifier(type: "ISBN_13", identifier: $0)]
                },
                imageLinks: nil,
                previewLink: nil,
                infoLink: nil,
                canonicalVolumeLink: nil,
                averageRating: nil,
                ratingsCount: nil
            ),
            accessInfo: nil,
            saleInfo: nil
        )
    }
}
