import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingShareURLClassifierTests {
    @Test func classifiesAllowedProviderURLs() throws {
        let apple = try #require(ReadingShareURLClassifier.classify(URL(string: "https://books.apple.com/us/book/demo/id123")!))
        let kindle = try #require(ReadingShareURLClassifier.classify(URL(string: "https://read.amazon.com/kp/embed?asin=B08TEST123")!))
        let google = try #require(ReadingShareURLClassifier.classify(URL(string: "https://play.google.com/store/books/details?id=abc123")!))
        let other = try #require(ReadingShareURLClassifier.classify(URL(string: "https://publisher.example/books/demo")!))

        #expect(apple.provider == .appleBooks)
        #expect(kindle.provider == .kindle)
        #expect(google.provider == .googleBooks)
        #expect(other.provider == .other)
    }

    @Test func rejectsUnsafeURLs() {
        #expect(ReadingShareURLClassifier.classify(URL(string: "http://books.apple.com/us/book/demo/id123")!) == nil)
        #expect(ReadingShareURLClassifier.classify(URL(string: "kindle://book/B08TEST123")!) == nil)
        #expect(ReadingShareURLClassifier.classify(URL(string: "https://192.168.0.1/book")!) == nil)
        #expect(ReadingShareURLClassifier.classify(URL(string: "https://localhost/book")!) == nil)
    }
}
