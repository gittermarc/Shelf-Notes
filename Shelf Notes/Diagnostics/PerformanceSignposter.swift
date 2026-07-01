import Foundation
import os

enum PerformanceSignposter {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "ShelfNotes",
        category: "Performance"
    )

    @discardableResult
    static func begin(_ name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    static func end(_ name: StaticString, id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    static func measure<T>(_ name: StaticString, work: () throws -> T) rethrows -> T {
        let id = begin(name)
        defer { end(name, id: id) }
        return try work()
    }

    static func measureAsync<T>(_ name: StaticString, work: () async throws -> T) async rethrows -> T {
        let id = begin(name)
        defer { end(name, id: id) }
        return try await work()
    }
}