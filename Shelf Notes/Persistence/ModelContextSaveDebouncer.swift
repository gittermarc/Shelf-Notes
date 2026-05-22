import Foundation

/// Coalesces multiple UI-triggered save requests into one delayed save.
///
/// The coordinator is intentionally persistence-agnostic so it can be tested with a
/// simple fake save closure and reused for SwiftData `ModelContext` saves from views.
@MainActor
final class ModelContextSaveDebouncer {
    private let delayNanoseconds: UInt64
    private var pendingTask: Task<Void, Never>?
    private var pendingSave: (@MainActor () -> Void)?

    nonisolated init(delayNanoseconds: UInt64 = 350_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    var hasPendingSave: Bool {
        pendingSave != nil
    }

    func schedule(_ save: @escaping @MainActor () -> Void) {
        pendingSave = save
        pendingTask?.cancel()

        pendingTask = Task { [weak self, delayNanoseconds] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            self?.runPendingSave()
        }
    }

    func flush() {
        pendingTask?.cancel()
        pendingTask = nil
        runPendingSave()
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingSave = nil
    }

    private func runPendingSave() {
        let save = pendingSave
        pendingSave = nil
        pendingTask = nil
        save?()
    }
}
