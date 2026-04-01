import Foundation
import Combine
import SwiftData

@MainActor
final class CSVImportExportViewModel: ObservableObject {
    @Published var searchMode: CSVSearchMode = .auto
    @Published var importStatus: ReadingStatus = .toRead
    @Published var showingImporter = false
    @Published var showingExporter = false
    @Published var exportDoc = CSVExportDocument(data: Data())
    @Published var exportFileName = "shelf_notes_export.csv"
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var lastReport: CSVImportReport?
    @Published var lastError: String?

    func prepareExport(from books: [Book]) {
        exportDoc = CSVExportDocument(data: CSVExportBuilder.data(from: books))
    }

    func handleImportPickerFailure(_ error: Error) {
        lastError = error.localizedDescription
    }

    func handleExportFailure(_ error: Error) {
        lastError = error.localizedDescription
    }

    func importCSV(from url: URL, books: [Book], modelContext: ModelContext) async {
        lastError = nil
        lastReport = nil
        isImporting = true
        importProgress = 0

        do {
            let data = try await readCSVData(from: url)
            let executor = CSVImportExecutor(modelContext: modelContext)
            let duplicateIndex = CSVImportDuplicateIndex(books: books)

            lastReport = try await executor.executeImport(
                data: data,
                searchMode: searchMode,
                importStatus: importStatus,
                duplicateIndex: duplicateIndex,
                progress: { [weak self] value in
                    self?.importProgress = value
                }
            )
        } catch {
            lastError = error.localizedDescription
        }

        isImporting = false
    }

    private func readCSVData(from url: URL) async throws -> Data {
        var accessed = false
        if url.startAccessingSecurityScopedResource() {
            accessed = true
        }
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try await Self.loadData(from: url)
    }

    private nonisolated static func loadData(from url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: url)
        }.value
    }
}
