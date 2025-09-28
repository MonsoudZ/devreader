import Foundation
import Combine

/// Manages web bookmarks and persistence
@MainActor
class WebStore: ObservableObject {
    @Published var bookmarks: [WebBookmark] = []
    @Published var currentURL: String = ""
    @Published var currentTitle: String = ""
    
    private let persistenceService: WebPersistenceProtocol
    
    init(persistenceService: WebPersistenceProtocol? = nil) {
        self.persistenceService = persistenceService ?? WebPersistenceService()
        loadBookmarks()
    }
    
    // MARK: - Web Management
    
    func navigateToURL(_ urlString: String) {
        currentURL = urlString
        currentTitle = extractTitle(from: urlString)
    }
    
    func addBookmark(title: String, url: String) {
        let bookmark = WebBookmark(
            title: title,
            url: url,
            createdDate: Date()
        )
        
        bookmarks.append(bookmark)
        saveBookmarks()
    }
    
    func deleteBookmark(_ bookmark: WebBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }
    
    func exportBookmarks() -> URL? {
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevReader_Bookmarks.html")
        
        let html = generateBookmarksHTML()
        try? html.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }
    
    private func extractTitle(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }
    
    private func generateBookmarksHTML() -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>DevReader Bookmarks</title>
            <meta charset="utf-8">
        </head>
        <body>
            <h1>DevReader Bookmarks</h1>
            <ul>
        """
        
        for bookmark in bookmarks {
            html += """
                <li><a href="\(bookmark.url)">\(bookmark.title)</a></li>
            """
        }
        
        html += """
            </ul>
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - Persistence
    
    private func saveBookmarks() {
        do {
            try persistenceService.saveBookmarks(bookmarks)
        } catch {
            print("Failed to save bookmarks: \(error)")
        }
    }
    
    private func loadBookmarks() {
        bookmarks = persistenceService.loadBookmarks()
    }
    
    func clearAllData() {
        bookmarks.removeAll()
        currentURL = ""
        currentTitle = ""
        persistenceService.clearAllData()
    }
}

// MARK: - Web Bookmark Model

struct WebBookmark: Identifiable, Codable {
    let id = UUID()
    var title: String
    var url: String
    let createdDate: Date
    
    init(title: String, url: String, createdDate: Date) {
        self.title = title
        self.url = url
        self.createdDate = createdDate
    }
}

// MARK: - Web Persistence Protocol

protocol WebPersistenceProtocol {
    func saveBookmarks(_ bookmarks: [WebBookmark]) throws
    func loadBookmarks() -> [WebBookmark]
    func clearAllData()
}

class WebPersistenceService: WebPersistenceProtocol {
    private let persistenceService = EnhancedPersistenceService.shared
    private let bookmarksKey = "DevReader.WebBookmarks.v1"
    
    func saveBookmarks(_ bookmarks: [WebBookmark]) throws {
        try persistenceService.saveCodable(bookmarks, forKey: bookmarksKey)
    }
    
    func loadBookmarks() -> [WebBookmark] {
        return persistenceService.loadCodable([WebBookmark].self, forKey: bookmarksKey) ?? []
    }
    
    func clearAllData() {
        persistenceService.clearAllData()
    }
}
