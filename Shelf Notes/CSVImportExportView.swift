//
//  CSVImportExportView.swift
//  Shelf Notes
//
//  Bulk import/export via CSV (title and/or ISBN).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum CSVSearchMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case isbn = "ISBN"
    case title = "Titel"

    var id: String { rawValue }
}

struct CSVImportReport: Identifiable {
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

    @State private var searchMode: CSVSearchMode = .auto
    @State private var importStatus: ReadingStatus = .toRead

    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDoc: CSVExportDocument = CSVExportDocument(data: Data())
    @State private var exportFileName: String = "shelf_notes_export.csv"

    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var lastReport: CSVImportReport?
    @State private var lastError: String?

    var body: some View {
        Form {
            Section("CSV Import") {
                Picker("Suche", selection: $searchMode) {
                    ForEach(CSVSearchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Picker("Status für Import", selection: $importStatus) {
                    ForEach(ReadingStatus.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                Button {
                    lastError = nil
                    showingImporter = true
                } label: {
                    Label("CSV importieren", systemImage: "square.and.arrow.down")
                }
                .disabled(isImporting)

                if isImporting {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: importProgress)
                        Text("Import läuft … \(Int(importProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Text("Pflicht: pro Zeile mindestens **Titel** oder **ISBN**.\nUnterstützte Spalten: title/titel und isbn/isbn13.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let report = lastReport {
                    Text(report.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if showExportSection {
                Section("CSV Export") {
                    Button {
                        prepareExport()
                        showingExporter = true
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
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { @MainActor in
                    await runImport(from: url)
                }
            case .failure(let err):
                lastError = err.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDoc,
            contentType: .commaSeparatedText,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let err):
                lastError = err.localizedDescription
            }
        }
    }

    private func prepareExport() {
        let rows: [CSVRow] = books.map { b in
            CSVRow(title: b.title, isbn: b.isbn13 ?? "")
        }
        exportDoc = CSVExportDocument(data: CSVCodec.encode(rows, delimiter: ",", includeHeader: true))
    }

    @MainActor
    private func runImport(from url: URL) async {
        lastError = nil
        lastReport = nil

        isImporting = true
        importProgress = 0

        var accessed = false
        if url.startAccessingSecurityScopedResource() {
            accessed = true
        }
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try CSVCodec.decode(data)
            let rawRows = decoded.rows
            let totalRows = rawRows.count

            var report = CSVImportReport(
                totalRows: totalRows,
                validRows: 0,
                imported: 0,
                duplicatesSkipped: 0,
                notFound: 0,
                invalidRows: 0,
                errors: 0
            )

            // Build duplicate sets
            var existingISBNs: Set<String> = Set(
                books
                    .compactMap { $0.isbn13?.filter(\.isNumber) }
                    .filter { !$0.isEmpty }
            )
            var existingVolumeIDs: Set<String> = Set(
                books
                    .compactMap { $0.googleVolumeID }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
            var existingTitles: Set<String> = Set(
                books
                    .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )

            let client = GoogleBooksClient.shared

            let totalForProgress = max(rawRows.count, 1)

            for (idx, row) in rawRows.enumerated() {
                // Progress (0..1)
                importProgress = Double(idx) / Double(totalForProgress)

                // Mandatory: at least one of title/isbn.
                guard row.hasRequiredField else {
                    report.invalidRows += 1
                    continue
                }

                let trimmedTitle = row.normalizedTitle
                let cleanedISBN = row.normalizedISBN

                // Decide search key
                let useISBN: Bool
                switch searchMode {
                case .isbn:
                    useISBN = true
                case .title:
                    useISBN = false
                case .auto:
                    useISBN = !cleanedISBN.isEmpty
                }

                if useISBN {
                    guard !cleanedISBN.isEmpty else {
                        report.invalidRows += 1
                        continue
                    }
                    if existingISBNs.contains(cleanedISBN) {
                        report.duplicatesSkipped += 1
                        continue
                    }
                } else {
                    guard !trimmedTitle.isEmpty else {
                        report.invalidRows += 1
                        continue
                    }
                    let norm = trimmedTitle.lowercased()
                    if existingTitles.contains(norm), cleanedISBN.isEmpty {
                        report.duplicatesSkipped += 1
                        continue
                    }
                }

                do {
                    let query: String
                    if useISBN {
                        query = "isbn:\(cleanedISBN)"
                    } else {
                        let safe = trimmedTitle.replacingOccurrences(of: "\"", with: "")
                        query = "intitle:\"\(safe)\""
                    }

                    let result = try await client.searchVolumesWithDebug(query: query, maxResults: 10)
                    let volumes = result.volumes

                    guard !volumes.isEmpty else {
                        report.notFound += 1
                        continue
                    }

                    // Best match selection
                    let selected: GoogleBookVolume
                    if useISBN, !cleanedISBN.isEmpty {
                        selected = volumes.first(where: { v in
                            let vIsbn = (v.isbn13 ?? "").filter(\.isNumber)
                            return !vIsbn.isEmpty && vIsbn == cleanedISBN
                        }) ?? volumes[0]
                    } else {
                        selected = volumes[0]
                    }

                    if existingVolumeIDs.contains(selected.id) {
                        report.duplicatesSkipped += 1
                        continue
                    }

                    let book = selected.toBook(status: importStatus)

                    // If we imported via ISBN but Google doesn't provide one, still keep the user's input.
                    if useISBN, book.isbn13 == nil, !cleanedISBN.isEmpty {
                        book.isbn13 = cleanedISBN
                    }
                    // If we imported via title but Google returns a different/empty title, keep the user's.
                    if !useISBN, !trimmedTitle.isEmpty, book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        book.title = trimmedTitle
                    }

                    modelContext.insert(book)
                    modelContext.saveWithDiagnostics()

                    // Update duplicate sets
                    if let v = book.googleVolumeID, !v.isEmpty { existingVolumeIDs.insert(v) }
                    let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !t.isEmpty { existingTitles.insert(t) }
                    if let i = book.isbn13?.filter(\.isNumber), !i.isEmpty { existingISBNs.insert(i) }

                    // Generate + sync thumbnail cover (best effort).
                    await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)

                    report.imported += 1
                } catch {
                    report.errors += 1
                }
            }

            report.validRows = max(0, report.totalRows - report.invalidRows)

            importProgress = 1
            lastReport = report
        } catch {
            lastError = error.localizedDescription
        }

        isImporting = false
    }
}
