import Foundation
import SwiftData

@MainActor
struct CSVImportExecutor {
    typealias SearchVolumes = (String) async throws -> [GoogleBookVolume]
    typealias SaveBook = (Book) -> Void
    typealias BackfillThumbnail = (Book) async -> Void

    let searchVolumes: SearchVolumes
    let saveBook: SaveBook
    let backfillThumbnail: BackfillThumbnail

    init(
        searchVolumes: @escaping SearchVolumes,
        saveBook: @escaping SaveBook,
        backfillThumbnail: @escaping BackfillThumbnail
    ) {
        self.searchVolumes = searchVolumes
        self.saveBook = saveBook
        self.backfillThumbnail = backfillThumbnail
    }

    init(modelContext: ModelContext) {
        self.searchVolumes = { query in
            let result = try await GoogleBooksClient.shared.searchVolumesWithDebug(query: query, maxResults: 10)
            return result.volumes
        }
        self.saveBook = { book in
            modelContext.insert(book)
            modelContext.saveWithDiagnostics()
        }
        self.backfillThumbnail = { book in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
        }
    }

    func executeImport(
        data: Data,
        searchMode: CSVSearchMode,
        importStatus: ReadingStatus,
        duplicateIndex: CSVImportDuplicateIndex,
        progress: @escaping (Double) -> Void
    ) async throws -> CSVImportReport {
        let rows = try await Self.decodeRows(from: data)
        return await executeImport(
            rows: rows,
            searchMode: searchMode,
            importStatus: importStatus,
            duplicateIndex: duplicateIndex,
            progress: progress
        )
    }

    func executeImport(
        rows: [CSVRow],
        searchMode: CSVSearchMode,
        importStatus: ReadingStatus,
        duplicateIndex: CSVImportDuplicateIndex,
        progress: @escaping (Double) -> Void
    ) async -> CSVImportReport {
        var report = CSVImportReport(
            totalRows: rows.count,
            validRows: 0,
            imported: 0,
            duplicatesSkipped: 0,
            notFound: 0,
            invalidRows: 0,
            errors: 0
        )

        var duplicateIndex = duplicateIndex
        let totalForProgress = max(rows.count, 1)

        for (index, row) in rows.enumerated() {
            progress(Double(index) / Double(totalForProgress))

            guard row.hasRequiredField else {
                report.invalidRows += 1
                continue
            }

            let trimmedTitle = row.normalizedTitle
            let cleanedISBN = row.normalizedISBN
            let useISBN = shouldUseISBN(searchMode: searchMode, normalizedISBN: cleanedISBN)

            if useISBN {
                guard !cleanedISBN.isEmpty else {
                    report.invalidRows += 1
                    continue
                }
                if duplicateIndex.contains(isbn: cleanedISBN) {
                    report.duplicatesSkipped += 1
                    continue
                }
            } else {
                guard !trimmedTitle.isEmpty else {
                    report.invalidRows += 1
                    continue
                }
                if cleanedISBN.isEmpty && duplicateIndex.contains(title: trimmedTitle) {
                    report.duplicatesSkipped += 1
                    continue
                }
            }

            do {
                let query = searchQuery(
                    title: trimmedTitle,
                    normalizedISBN: cleanedISBN,
                    useISBN: useISBN
                )
                let volumes = try await searchVolumes(query)

                guard !volumes.isEmpty else {
                    report.notFound += 1
                    continue
                }

                let selected = selectBestVolume(
                    from: volumes,
                    normalizedISBN: cleanedISBN,
                    useISBN: useISBN
                )

                if duplicateIndex.contains(volumeID: selected.id) {
                    report.duplicatesSkipped += 1
                    continue
                }

                let book = makeBook(
                    from: selected,
                    importStatus: importStatus,
                    fallbackTitle: trimmedTitle,
                    fallbackISBN: cleanedISBN,
                    useISBN: useISBN
                )

                saveBook(book)
                duplicateIndex.register(book: book)
                await backfillThumbnail(book)
                report.imported += 1
            } catch {
                report.errors += 1
            }
        }

        report.validRows = max(0, report.totalRows - report.invalidRows)
        progress(1)
        return report
    }

    private func shouldUseISBN(searchMode: CSVSearchMode, normalizedISBN: String) -> Bool {
        switch searchMode {
        case .isbn:
            return true
        case .title:
            return false
        case .auto:
            return !normalizedISBN.isEmpty
        }
    }

    private func searchQuery(title: String, normalizedISBN: String, useISBN: Bool) -> String {
        if useISBN {
            return "isbn:\(normalizedISBN)"
        }

        let safeTitle = title.replacingOccurrences(of: "\"", with: "")
        return "intitle:\"\(safeTitle)\""
    }

    private func selectBestVolume(
        from volumes: [GoogleBookVolume],
        normalizedISBN: String,
        useISBN: Bool
    ) -> GoogleBookVolume {
        guard useISBN, !normalizedISBN.isEmpty else {
            return volumes[0]
        }

        return volumes.first(where: { volume in
            CSVImportDuplicateIndex.normalizedISBN(volume.isbn13) == normalizedISBN
        }) ?? volumes[0]
    }

    private func makeBook(
        from volume: GoogleBookVolume,
        importStatus: ReadingStatus,
        fallbackTitle: String,
        fallbackISBN: String,
        useISBN: Bool
    ) -> Book {
        let book = volume.toBook(status: importStatus)

        if useISBN, book.isbn13 == nil, !fallbackISBN.isEmpty {
            book.isbn13 = fallbackISBN
        }

        if !useISBN,
           !fallbackTitle.isEmpty,
           book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            book.title = fallbackTitle
        }

        return book
    }

    private nonisolated static func decodeRows(from data: Data) async throws -> [CSVRow] {
        try await Task.detached(priority: .userInitiated) {
            try CSVCodec.decode(data).rows
        }.value
    }
}
