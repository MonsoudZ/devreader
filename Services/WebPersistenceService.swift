import Foundation

protocol WebPersistenceProtocol: Sendable {
    func saveBookmarks(_ bookmarks: [WebBookmark]) throws
    func loadBookmarks() -> [WebBookmark]
    func clearAllData()
}

final class WebPersistenceService: WebPersistenceProtocol, @unchecked Sendable {
    private let persistenceService = EnhancedPersistenceService.shared
    private let bookmarksKey = "DevReader.WebBookmarks.v1"

    func saveBookmarks(_ bookmarks: [WebBookmark]) throws {
        try persistenceService.saveCodable(bookmarks, forKey: bookmarksKey)
    }

    func loadBookmarks() -> [WebBookmark] {
        return persistenceService.loadCodable([WebBookmark].self, forKey: bookmarksKey) ?? []
    }

    func clearAllData() {
        persistenceService.deleteKey(bookmarksKey)
    }
}
