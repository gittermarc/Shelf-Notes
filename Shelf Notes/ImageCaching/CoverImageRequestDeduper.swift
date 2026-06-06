//
//  CoverImageRequestDeduper.swift
//  Shelf Notes
//

import Foundation

nonisolated enum CoverImageRequestKey {
    static func make(for url: URL) -> String {
        let trimmed = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return url.absoluteString }

        guard var components = URLComponents(string: trimmed) else {
            return trimmed
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()

        return components.url?.absoluteString ?? trimmed
    }
}

/// Coalesces concurrent raw cover-data loads for the same normalized URL.
///
/// This keeps duplicate scroll-triggered requests from starting parallel network loads.
/// The shared task is intentionally unstructured so cancellation of one row does not
/// cancel the same request for other rows that still need the image.
nonisolated final class CoverImageRequestDeduper: @unchecked Sendable {
    static let shared = CoverImageRequestDeduper()

    private let lock = NSLock()
    private var tasksByKey: [String: Task<Data?, Never>] = [:]

    func data(
        for url: URL,
        operation: @escaping @Sendable () async -> Data?
    ) async -> Data? {
        let key = CoverImageRequestKey.make(for: url)

        let task = existingOrCreateTask(forKey: key, operation: operation)
        let result = await task.value

        removeTask(forKey: key)
        return result
    }

    func cancelAll() {
        lock.lock()
        let tasks = Array(tasksByKey.values)
        tasksByKey.removeAll()
        lock.unlock()

        for task in tasks {
            task.cancel()
        }
    }

    private func existingOrCreateTask(
        forKey key: String,
        operation: @escaping @Sendable () async -> Data?
    ) -> Task<Data?, Never> {
        lock.lock()
        defer { lock.unlock() }

        if let existing = tasksByKey[key] {
            return existing
        }

        let task = Task(priority: .userInitiated) {
            await operation()
        }
        tasksByKey[key] = task
        return task
    }

    private func removeTask(forKey key: String) {
        lock.lock()
        tasksByKey.removeValue(forKey: key)
        lock.unlock()
    }
}
