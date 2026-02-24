import SwiftUI
import SwiftData

// MARK: - Persistence
extension BookDetailView {

    /// Centralized save hook for the detail screen.
    ///
    /// Today this is an immediate save (behavior unchanged). Keeping it here makes it easy
    /// to introduce throttling later without touching every call site.
    @discardableResult
    func saveDetail(
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> Error? {
        modelContext.saveWithDiagnostics(file: file, line: line)
    }
}
