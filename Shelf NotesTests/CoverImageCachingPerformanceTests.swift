import Foundation
import Testing
@testable import Shelf_Notes

struct CoverImageCachingPerformanceTests {

    @Test func requestDeduperCoalescesConcurrentLoadsForSameURL() async {
        let deduper = CoverImageRequestDeduper()
        let url = URL(string: "https://example.com/covers/book.jpg")!
        let counter = CoverImageRequestDeduperCounter()

        async let first = deduper.data(for: url) {
            await counter.load()
        }
        async let second = deduper.data(for: url) {
            await counter.load()
        }
        async let third = deduper.data(for: url) {
            await counter.load()
        }

        let results = await [first, second, third]

        #expect(results == [Data([1]), Data([1]), Data([1])])
        #expect(await counter.value() == 1)
    }

    @Test func failureCacheBlocksRetriesUntilTTLExpires() {
        let cache = RemoteCoverFailureCache(ttl: 60)
        let url = URL(string: "https://example.com/missing-cover.jpg")!
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(cache.shouldSkip(url, now: start) == false)

        cache.recordFailure(for: url, now: start)

        #expect(cache.shouldSkip(url, now: start.addingTimeInterval(59)) == true)
        #expect(cache.shouldSkip(url, now: start.addingTimeInterval(61)) == false)
    }

    @Test func failureCacheCanBeCleared() {
        let cache = RemoteCoverFailureCache(ttl: 60)
        let url = URL(string: "https://example.com/missing-cover.jpg")!
        let start = Date(timeIntervalSince1970: 2_000)

        cache.recordFailure(for: url, now: start)
        #expect(cache.shouldSkip(url, now: start.addingTimeInterval(10)) == true)

        cache.clear()

        #expect(cache.shouldSkip(url, now: start.addingTimeInterval(10)) == false)
    }

    @Test func diskCachePrunesBelowConfiguredLimit() throws {
        let folderURL = try makeTemporaryCacheFolder()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let cache = ImageDiskCache(folderURL: folderURL, maxDiskUsageBytes: 70)

        cache.store(data: Data(repeating: 1, count: 40), for: URL(string: "https://example.com/a.jpg")!)
        cache.store(data: Data(repeating: 2, count: 40), for: URL(string: "https://example.com/b.jpg")!)
        cache.store(data: Data(repeating: 3, count: 40), for: URL(string: "https://example.com/c.jpg")!)

        #expect(cache.diskUsageBytes() <= 70)
    }

    @Test func diskCacheClearRemovesStoredEntries() throws {
        let folderURL = try makeTemporaryCacheFolder()
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let cache = ImageDiskCache(folderURL: folderURL, maxDiskUsageBytes: 1_024)
        let url = URL(string: "https://example.com/cover.jpg")!

        cache.store(data: Data(repeating: 7, count: 32), for: url)

        #expect(cache.data(for: url) == Data(repeating: 7, count: 32))

        cache.clearAll()

        #expect(cache.data(for: url) == nil)
        #expect(cache.diskUsageBytes() == 0)
    }

    private func makeTemporaryCacheFolder() throws -> URL {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfNotesImageDiskCacheTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }
}

private actor CoverImageRequestDeduperCounter {
    private var count = 0

    func load() async -> Data {
        count += 1
        try? await Task.sleep(nanoseconds: 20_000_000)
        return Data([UInt8(count)])
    }

    func value() -> Int {
        count
    }
}
