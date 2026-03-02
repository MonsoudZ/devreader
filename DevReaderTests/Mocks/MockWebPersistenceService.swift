import Foundation
@testable import DevReader

class MockWebPersistenceService: WebPersistenceProtocol {
    var bookmarks: [WebBookmark] = []
    var saveCallCount = 0
    var shouldThrowError = false

    func saveBookmarks(_ bookmarks: [WebBookmark]) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.bookmarks = bookmarks
        saveCallCount += 1
    }

    func loadBookmarks() -> [WebBookmark] {
        return bookmarks
    }

    func clearAllData() {
        bookmarks.removeAll()
        saveCallCount = 0
    }
}
