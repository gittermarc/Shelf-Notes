//
//  BookImportViewModel+DebugAndUndo.swift
//  Shelf Notes
//
//  Request debug helpers and undo/snackbar handling.
//

import Foundation
import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
extension BookImportViewModel {

    var lastRequestURLString: String? {
        lastDebugInfo?.requestURL
    }

    var lastRequestURLSanitized: String? {
        guard let raw = lastDebugInfo?.requestURL else { return nil }
        return Self.sanitizeURLRemovingKey(raw)
    }

    var lastResponseSnippet: String? {
        lastDebugInfo?.responseBodySnippet
    }

    var lastResponseHasErrorObject: Bool? {
        lastDebugInfo?.hasErrorObject
    }

    var lastResponseParsedTotalItems: Int? {
        lastDebugInfo?.parsedTotalItems
    }

    var lastRequestUsedApiKey: Bool? {
        lastDebugInfo?.usedApiKey
    }

    var lastRequestDebugSummary: String? {
        guard let d = lastDebugInfo else { return nil }
        var parts: [String] = []
        if let status = d.httpStatus {
            parts.append("HTTP \(status)")
        }
        parts.append(Self.formatBytes(d.responseBytes))
        if let ti = d.parsedTotalItems {
            parts.append("totalItems \(ti)")
        }
        parts.append(d.usedApiKey ? "key" : "no-key")
        return "Google: " + parts.joined(separator: " • ")
    }

    func hideUndo() {
        undoHideTask?.cancel()
        undoHideTask = nil
        withAnimation(.snappy) {
            undoPayload = nil
        }
    }

    func undoLastAdd(_ payload: UndoPayload, modelContext: ModelContext) async {
        undoHideTask?.cancel()
        undoHideTask = nil

        withAnimation(.snappy) {
            undoPayload = nil
        }

        let bookID = payload.bookID

        do {
            let fd = FetchDescriptor<Book>(predicate: #Predicate<Book> { $0.id == bookID })
            if let book = try modelContext.fetch(fd).first {
                modelContext.delete(book)
                modelContext.saveWithDiagnostics()
            }
        } catch {
            // ignore – UI is still consistent
        }

        addedVolumeIDs.remove(payload.volumeID)

        if sessionQuickAddCount > 0 { sessionQuickAddCount -= 1 }
        onQuickAddActiveChanged?(sessionQuickAddCount > 0)

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }

    func showUndo(for book: Book, volumeID: String, status: ReadingStatus) {
        undoHideTask?.cancel()
        undoHideTask = nil

        let payload = UndoPayload(
            bookID: book.id,
            volumeID: volumeID,
            title: book.title.isEmpty ? "Ohne Titel" : book.title,
            status: status,
            thumbnailURL: book.thumbnailURL
        )

        withAnimation(.snappy) {
            undoPayload = payload
        }

        undoHideTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            await MainActor.run {
                guard undoPayload?.id == payload.id else { return }
                withAnimation(.snappy) {
                    undoPayload = nil
                }
            }
        }
    }

    private static func formatBytes(_ bytes: Int) -> String {
        if bytes <= 0 { return "0 B" }
        if bytes < 1024 { return "\(bytes) B" }

        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        }

        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private static func sanitizeURLRemovingKey(_ urlString: String) -> String {
        guard var comps = URLComponents(string: urlString) else { return urlString }
        if let items = comps.queryItems, !items.isEmpty {
            comps.queryItems = items.filter { $0.name.lowercased() != "key" }
        }
        return comps.url?.absoluteString ?? urlString
    }
}
