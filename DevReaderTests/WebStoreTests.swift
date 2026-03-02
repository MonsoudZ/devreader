import XCTest
@testable import DevReader

@MainActor
final class WebStoreTests: XCTestCase {
    var store: WebStore!
    var mockPersistence: MockWebPersistenceService!

    override func setUp() {
        mockPersistence = MockWebPersistenceService()
        store = WebStore(persistenceService: mockPersistence)
    }

    override func tearDown() {
        store = nil
        mockPersistence = nil
    }

    // MARK: - Bookmark Tests

    func testAddBookmark() {
        store.addBookmark(title: "Apple", url: "https://apple.com")

        XCTAssertEqual(store.bookmarks.count, 1)
        XCTAssertEqual(store.bookmarks.first?.title, "Apple")
        XCTAssertEqual(store.bookmarks.first?.url, "https://apple.com")
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
    }

    func testDeleteBookmark() {
        store.addBookmark(title: "Apple", url: "https://apple.com")
        store.addBookmark(title: "Google", url: "https://google.com")

        guard let bookmark = store.bookmarks.first else {
            XCTFail("Store should have bookmarks"); return
        }
        store.deleteBookmark(bookmark)

        XCTAssertEqual(store.bookmarks.count, 1)
        XCTAssertEqual(store.bookmarks.first?.title, "Google")
    }

    func testNavigateToURL() {
        store.navigateToURL("https://example.com")

        XCTAssertEqual(store.currentURL, "https://example.com")
        XCTAssertEqual(store.currentTitle, "example.com")
    }

    func testExportBookmarks() {
        store.addBookmark(title: "Test", url: "https://test.com")

        let exportURL = store.exportBookmarks()

        XCTAssertNotNil(exportURL)
        if let url = exportURL {
            let html = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertNotNil(html)
            XCTAssertTrue(html?.contains("Test") ?? false)
            XCTAssertTrue(html?.contains("https://test.com") ?? false)
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testLoadOnInit() {
        let freshMock = MockWebPersistenceService()
        freshMock.bookmarks = [
            WebBookmark(title: "Preloaded", url: "https://pre.com", createdDate: Date())
        ]
        let newStore = WebStore(persistenceService: freshMock)
        // Keep newStore alive until XCTest teardown phase to avoid @MainActor deinit crash
        addTeardownBlock { [newStore] in _ = newStore }

        XCTAssertEqual(newStore.bookmarks.count, 1)
        XCTAssertEqual(newStore.bookmarks.first?.title, "Preloaded")
    }

    func testClearAllData() {
        store.addBookmark(title: "Test", url: "https://test.com")
        store.navigateToURL("https://nav.com")

        store.clearAllData()

        XCTAssertTrue(store.bookmarks.isEmpty)
        XCTAssertEqual(store.currentURL, "")
        XCTAssertEqual(store.currentTitle, "")
    }

    func testSavePersistenceError() {
        mockPersistence.shouldThrowError = true

        // Should not crash
        store.addBookmark(title: "Test", url: "https://test.com")

        // Bookmark is still added to in-memory store
        XCTAssertEqual(store.bookmarks.count, 1)
    }
}
