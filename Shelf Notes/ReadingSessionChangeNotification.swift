import Foundation

extension Notification.Name {
    static let readingSessionsDidChange = Notification.Name("ShelfNotesReadingSessionsDidChange")
}

enum ReadingSessionChangeNotifier {
    static func post() {
        NotificationCenter.default.post(name: .readingSessionsDidChange, object: nil)
    }
}
