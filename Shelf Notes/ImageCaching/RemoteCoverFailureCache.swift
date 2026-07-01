//
//  RemoteCoverFailureCache.swift
//  Shelf Notes
//

import Foundation

/// Short-lived cache for failing remote cover URLs.
///
/// It prevents repeated immediate retries for broken cover candidates while scrolling.
nonisolated final class RemoteCoverFailureCache: @unchecked Sendable {
    static let shared = RemoteCoverFailureCache()

    static let defaultTTL: TimeInterval = 10 * 60

    private let ttl: TimeInterval
    private let lock = NSLock()
    private var blockedUntilByKey: [String: Date] = [:]

    init(ttl: TimeInterval = defaultTTL) {
        self.ttl = max(0, ttl)
    }

    func shouldSkip(_ url: URL, now: Date = Date()) -> Bool {
        let key = CoverImageRequestKey.make(for: url)

        lock.lock()
        defer { lock.unlock() }

        guard let blockedUntil = blockedUntilByKey[key] else {
            return false
        }

        if blockedUntil > now {
            return true
        }

        blockedUntilByKey.removeValue(forKey: key)
        return false
    }

    func recordFailure(for url: URL, now: Date = Date()) {
        let key = CoverImageRequestKey.make(for: url)
        let blockedUntil = now.addingTimeInterval(ttl)

        lock.lock()
        blockedUntilByKey[key] = blockedUntil
        lock.unlock()
    }

    func recordSuccess(for url: URL) {
        let key = CoverImageRequestKey.make(for: url)

        lock.lock()
        blockedUntilByKey.removeValue(forKey: key)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        blockedUntilByKey.removeAll()
        lock.unlock()
    }
}
