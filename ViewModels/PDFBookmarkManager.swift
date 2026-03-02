import Foundation
import Combine

@MainActor
final class PDFBookmarkManager: ObservableObject {
    @Published var bookmarks: Set<Int> = []
    @Published private(set) var recentDocuments: [URL] = []
    @Published private(set) var pinnedDocuments: [URL] = []

    private let bookmarksKey = "DevReader.Bookmarks.v1"
    private let recentsKey = "DevReader.Recents.v1"
    private let pinnedKey = "DevReader.Pinned.v1"

    func toggleBookmark(_ pageIndex: Int, for url: URL?) {
        if bookmarks.contains(pageIndex) {
            bookmarks.remove(pageIndex)
        } else {
            bookmarks.insert(pageIndex)
        }
        saveBookmarks(for: url)
    }

    func isBookmarked(_ pageIndex: Int) -> Bool {
        bookmarks.contains(pageIndex)
    }

    func loadBookmarks(for url: URL?) {
        guard let url = url else { return }
        let key = PersistenceService.key(bookmarksKey, for: url)
        if let arr: [Int] = PersistenceService.loadCodable([Int].self, forKey: key) {
            bookmarks = Set(arr)
        }
    }

    func saveBookmarks(for url: URL?) {
        guard let url = url else { return }
        let key = PersistenceService.key(bookmarksKey, for: url)
        PersistenceService.saveCodable(Array(bookmarks), forKey: key)
    }

    func loadRecents() {
        if let arr: [URL] = PersistenceService.loadCodable([URL].self, forKey: recentsKey) {
            recentDocuments = arr.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        if let pins: [URL] = PersistenceService.loadCodable([URL].self, forKey: pinnedKey) {
            pinnedDocuments = pins.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    func saveRecents() {
        PersistenceService.saveCodable(recentDocuments, forKey: recentsKey)
        PersistenceService.saveCodable(pinnedDocuments, forKey: pinnedKey)
    }

    func addRecent(_ url: URL) {
        if let idx = pinnedDocuments.firstIndex(of: url) {
            pinnedDocuments.remove(at: idx)
            pinnedDocuments.insert(url, at: 0)
        } else {
            recentDocuments.removeAll { $0 == url }
            recentDocuments.insert(url, at: 0)
            let cap = max(0, 10 - pinnedDocuments.count)
            if recentDocuments.count > cap {
                recentDocuments.removeLast(recentDocuments.count - cap)
            }
        }
        saveRecents()
    }

    func pin(_ url: URL) {
        recentDocuments.removeAll { $0 == url }
        pinnedDocuments.removeAll { $0 == url }
        pinnedDocuments.insert(url, at: 0)
        saveRecents()
    }

    func unpin(_ url: URL) {
        pinnedDocuments.removeAll { $0 == url }
        addRecent(url)
    }

    func isPinned(_ url: URL) -> Bool {
        pinnedDocuments.contains(url)
    }

    func clearRecents() {
        recentDocuments.removeAll()
        saveRecents()
    }

    func resetAll() {
        bookmarks.removeAll()
        recentDocuments.removeAll()
        pinnedDocuments.removeAll()
    }
}
