import Foundation
import Combine
import os.log

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
        bookmarks.removeAll()
        guard let url = url else { return }
        let key = PersistenceService.key(bookmarksKey, for: url)
        let legacy = PersistenceService.legacyKey(bookmarksKey, for: url)
        if let arr: [Int] = PersistenceService.loadCodableWithMigration([Int].self, forKey: key, legacyKey: legacy) {
            bookmarks = Set(arr)
        }
    }

    func saveBookmarks(for url: URL?) {
        guard let url = url else { return }
        let key = PersistenceService.key(bookmarksKey, for: url)
        do {
            try PersistenceService.saveCodable(Array(bookmarks), forKey: key)
        } catch {
            logError(AppLog.persistence, "Failed to save bookmarks: \(error.localizedDescription)")
        }
    }

    func loadRecents() {
        let rawRecents: [URL]? = PersistenceService.loadCodable([URL].self, forKey: recentsKey)
        let rawPinned: [URL]? = PersistenceService.loadCodable([URL].self, forKey: pinnedKey)

        // Show immediately, then filter stale entries off main thread
        if let arr = rawRecents { recentDocuments = arr }
        if let pins = rawPinned { pinnedDocuments = pins }

        Task.detached(priority: .utility) { [recents = rawRecents, pinned = rawPinned] in
            let fm = FileManager.default
            let filteredRecents = recents?.filter { fm.fileExists(atPath: $0.path) }
            let filteredPinned = pinned?.filter { fm.fileExists(atPath: $0.path) }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let r = filteredRecents { self.recentDocuments = r }
                if let p = filteredPinned { self.pinnedDocuments = p }
            }
        }
    }

    func saveRecents() {
        do {
            try PersistenceService.saveCodable(recentDocuments, forKey: recentsKey)
        } catch {
            logError(AppLog.persistence, "Failed to save recents: \(error.localizedDescription)")
        }
        do {
            try PersistenceService.saveCodable(pinnedDocuments, forKey: pinnedKey)
        } catch {
            logError(AppLog.persistence, "Failed to save pinned: \(error.localizedDescription)")
        }
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
        saveRecents()
    }
}
