import Foundation
import Testing
@testable import Shelf_Notes

struct ShelfNotesDeepLinkTests {
    @Test func parsesLibraryDeepLink() throws {
        let route = try #require(ShelfNotesDeepLink.route(from: url("shelfnotes://library")))
        #expect(route.destination == .library)
    }

    @Test func parsesProgressDeepLink() throws {
        let route = try #require(ShelfNotesDeepLink.route(from: url("shelfnotes://progress")))
        #expect(route.destination == .progress)
    }

    @Test func parsesBookDeepLinkWithID() throws {
        let id = fixedID(42)
        let route = try #require(ShelfNotesDeepLink.route(from: url("shelfnotes://book?id=\(id.uuidString)")))
        #expect(route.destination == .book(id))
    }

    @Test func acceptsBookIDQueryNameForCompatibility() throws {
        let id = fixedID(43)
        let route = try #require(ShelfNotesDeepLink.route(from: url("shelfnotes://book?bookID=\(id.uuidString)")))
        #expect(route.destination == .book(id))
    }

    @Test func invalidBookDeepLinkFallsBackToLibrary() throws {
        let route = try #require(ShelfNotesDeepLink.route(from: url("shelfnotes://book?id=not-a-uuid")))
        #expect(route.destination == .library)
    }

    @Test func unknownShelfNotesHostIsIgnoredSoLiveActivityLinksCanHandleThemselves() {
        let route = ShelfNotesDeepLink.route(from: url("shelfnotes://reading-session?bookID=00000000-0000-0000-0000-000000000001"))
        #expect(route == nil)
    }

    @Test func unrelatedSchemeIsIgnored() {
        let route = ShelfNotesDeepLink.route(from: url("https://example.com/library"))
        #expect(route == nil)
    }

    private func url(_ rawValue: String) -> URL {
        URL(string: rawValue) ?? URL(fileURLWithPath: "/invalid")
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
