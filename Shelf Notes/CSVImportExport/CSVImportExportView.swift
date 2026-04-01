//
//  CSVImportExportView.swift
//  Shelf Notes
//
//  Bulk import/export via CSV (title and/or ISBN).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum CSVSearchMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case isbn = "ISBN"
    case title = "Titel"

    var id: String { rawValue }
}

struct CSVImportReport: Identifiable, Sendable {
    let id = UUID()
    var totalRows: Int
    var validRows: Int
    var imported: Int
    var duplicatesSkipped: Int
    var notFound: Int
    var invalidRows: Int
    var errors: Int

    var summaryText: String {
        "Import: \(imported) neu • \(duplicatesSkipped) Duplikate • \(notFound) nicht gefunden • \(invalidRows) ungültig • \(errors) Fehler"
    }
}

/// FileDocument for CSV export.
struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct CSVImportExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]

    var title: String = "CSV Import/Export"
    var showExportSection: Bool = true
    var showDoneButton: Bool = false

    @StateObject private var viewModel = CSVImportExportViewModel()

    var body: some View {
        Form {
            Section("CSV Import") {
                Picker("Suche", selection: $viewModel.searchMode) {
                    ForEach(CSVSearchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Picker("Status für Import", selection: $viewModel.importStatus) {
                    ForEach(ReadingStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }

                Button {
                    viewModel.lastError = nil
                    viewModel.showingImporter = true
                } label: {
                    Label("CSV importieren", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isImporting)

                if viewModel.isImporting {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: viewModel.importProgress)
                        Text("Import läuft … \(Int(viewModel.importProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Text("Pflicht: pro Zeile mindestens **Titel** oder **ISBN**.\nUnterstützte Spalten: title/titel und isbn/isbn13.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let report = viewModel.lastReport {
                    Text(report.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastError = viewModel.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if showExportSection {
                Section("CSV Export") {
                    Button {
                        viewModel.prepareExport(from: books)
                        viewModel.showingExporter = true
                    } label: {
                        Label("CSV exportieren", systemImage: "square.and.arrow.up")
                    }
                    .disabled(books.isEmpty)

                    Text("Exportiert aktuell nur Titel und ISBN. Erweiterungen können später drauf.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Beispiel") {
                Text("title,isbn13\nThe Hobbit,9780261103344")
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { @MainActor in
                    await viewModel.importCSV(from: url, books: books, modelContext: modelContext)
                }
            case .failure(let error):
                viewModel.handleImportPickerFailure(error)
            }
        }
        .fileExporter(
            isPresented: $viewModel.showingExporter,
            document: viewModel.exportDoc,
            contentType: .commaSeparatedText,
            defaultFilename: viewModel.exportFileName
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                viewModel.handleExportFailure(error)
            }
        }
    }
}
