import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class PDFControllerTests: XCTestCase {
    private var ctrl: PDFController!

    override func setUp() {
        super.setUp()
        ctrl = PDFController()
    }

    override func tearDown() {
        ctrl = nil
        // Clear JSON storage data to prevent test interference
        let dataDir = JSONStorageService.dataDirectory
        try? FileManager.default.removeItem(at: dataDir)
        JSONStorageService.ensureDirectories()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDoc(pageCount: Int) -> PDFDocument {
        let doc = PDFDocument()
        for i in 0..<pageCount {
            doc.insert(PDFPage(), at: i)
        }
        return doc
    }

    private func makeTempURL(_ prefix: String = "test") -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)_\(UUID().uuidString).pdf")
    }

    // MARK: - Existing tests (refactored into setUp/tearDown)

    func testPagePersistenceKeyedByURL() {
        let doc1 = makeDoc(pageCount: 1)
        let doc2 = makeDoc(pageCount: 1)
        let tmp1 = makeTempURL("a")
        let tmp2 = makeTempURL("b")

        ctrl.loadForTesting(document: doc1, url: tmp1)
        ctrl.goToPage(0)

        ctrl.loadForTesting(document: doc2, url: tmp2)
        ctrl.goToPage(0)

        ctrl.loadForTesting(document: doc1, url: tmp1)
        XCTAssertGreaterThanOrEqual(ctrl.currentPageIndex, 0)
    }

    func testBookmarksPersist() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL("c")

        ctrl.loadForTesting(document: doc, url: tmp)
        ctrl.bookmarkManager.toggleBookmark(0, for: ctrl.currentPDFURL)
        XCTAssertTrue(ctrl.bookmarkManager.isBookmarked(0))

        ctrl.loadForTesting(document: doc, url: tmp)
        XCTAssertTrue(ctrl.bookmarkManager.isBookmarked(0))
    }

    // MARK: - goToPage

    func testGoToPageBoundsChecking() {
        let doc = makeDoc(pageCount: 5)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        // Negative index is a no-op
        ctrl.goToPage(-1)
        XCTAssertEqual(ctrl.currentPageIndex, 0)

        // Beyond last page is a no-op
        ctrl.goToPage(5)
        XCTAssertEqual(ctrl.currentPageIndex, 0)

        // Equal to page count is a no-op
        ctrl.goToPage(5)
        XCTAssertEqual(ctrl.currentPageIndex, 0)

        // Valid page works
        ctrl.goToPage(3)
        XCTAssertEqual(ctrl.currentPageIndex, 3)
    }

    func testGoToPageUpdatesReadingProgress() {
        let doc = makeDoc(pageCount: 10)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.goToPage(4) // page 5 of 10
        XCTAssertEqual(ctrl.readingProgress, 5.0 / 10.0, accuracy: 0.001)

        ctrl.goToPage(9) // page 10 of 10
        XCTAssertEqual(ctrl.readingProgress, 1.0, accuracy: 0.001)
    }

    // MARK: - Search

    func testClearSearchResetsState() {
        let doc = makeDoc(pageCount: 3)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        // Manually set some search state
        ctrl.searchManager.searchQuery = "test"
        ctrl.searchManager.searchIndex = 2

        ctrl.searchManager.clearSearch()
        XCTAssertEqual(ctrl.searchManager.searchQuery, "")
        XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
        XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
    }

    func testSearchEmptyQueryClearsResults() {
        let doc = makeDoc(pageCount: 3)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        // Search with whitespace-only query should clear
        ctrl.searchManager.performSearch("   ", in: ctrl.document)
        XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
        XCTAssertEqual(ctrl.searchManager.searchQuery, "")
    }

    func testSearchNoOpsWhenEmpty() {
        let doc = makeDoc(pageCount: 3)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        // No results — next/prev/jump should not crash
        XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
        ctrl.searchManager.nextSearchResult(in: ctrl.document)
        ctrl.searchManager.previousSearchResult(in: ctrl.document)
        ctrl.searchManager.jumpToSearchResult(5, in: ctrl.document)
        XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
    }

    // MARK: - Recents

    func testAddRecentAddsToList() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.bookmarkManager.addRecent(tmp)
        XCTAssertTrue(ctrl.bookmarkManager.recentDocuments.contains(tmp))
    }

    func testAddRecentMaintainsCapOf10() {
        let doc = makeDoc(pageCount: 1)
        let baseURL = makeTempURL()
        ctrl.loadForTesting(document: doc, url: baseURL)

        // Add 12 recents
        var urls: [URL] = []
        for i in 0..<12 {
            let url = makeTempURL("recent\(i)")
            urls.append(url)
            ctrl.bookmarkManager.addRecent(url)
        }

        XCTAssertLessThanOrEqual(ctrl.bookmarkManager.recentDocuments.count, 10)
    }

    func testAddRecentNoDuplicates() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.bookmarkManager.addRecent(tmp)
        ctrl.bookmarkManager.addRecent(tmp)
        ctrl.bookmarkManager.addRecent(tmp)

        let occurrences = ctrl.bookmarkManager.recentDocuments.filter { $0 == tmp }.count
        XCTAssertEqual(occurrences, 1)
    }

    // MARK: - Pinning

    func testPinAndUnpin() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.bookmarkManager.addRecent(tmp)
        XCTAssertTrue(ctrl.bookmarkManager.recentDocuments.contains(tmp))

        ctrl.bookmarkManager.pin(tmp)
        XCTAssertTrue(ctrl.bookmarkManager.isPinned(tmp))
        XCTAssertTrue(ctrl.bookmarkManager.pinnedDocuments.contains(tmp))
        XCTAssertFalse(ctrl.bookmarkManager.recentDocuments.contains(tmp))

        ctrl.bookmarkManager.unpin(tmp)
        XCTAssertFalse(ctrl.bookmarkManager.isPinned(tmp))
        XCTAssertTrue(ctrl.bookmarkManager.recentDocuments.contains(tmp))
    }

    func testPinnedReducesRecentsCap() {
        let doc = makeDoc(pageCount: 1)
        let baseURL = makeTempURL()
        ctrl.loadForTesting(document: doc, url: baseURL)

        // Pin 3 URLs
        for i in 0..<3 {
            ctrl.bookmarkManager.pin(makeTempURL("pin\(i)"))
        }

        // Add 10 recents — cap should be 10 - 3 = 7
        for i in 0..<10 {
            ctrl.bookmarkManager.addRecent(makeTempURL("r\(i)"))
        }

        XCTAssertLessThanOrEqual(ctrl.bookmarkManager.recentDocuments.count, 7)
    }

    // MARK: - Clear Session

    func testClearSessionResetsAllState() {
        let doc = makeDoc(pageCount: 5)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.goToPage(3)
        ctrl.bookmarkManager.toggleBookmark(2, for: ctrl.currentPDFURL)
        ctrl.searchManager.searchQuery = "test"

        ctrl.clearSession()

        XCTAssertNil(ctrl.document)
        XCTAssertEqual(ctrl.currentPageIndex, 0)
        XCTAssertTrue(ctrl.bookmarkManager.bookmarks.isEmpty)
        XCTAssertEqual(ctrl.searchManager.searchQuery, "")
        XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
    }

    // MARK: - Bookmarks

    func testBookmarkToggle() {
        let doc = makeDoc(pageCount: 5)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        XCTAssertFalse(ctrl.bookmarkManager.isBookmarked(2))

        ctrl.bookmarkManager.toggleBookmark(2, for: ctrl.currentPDFURL)
        XCTAssertTrue(ctrl.bookmarkManager.isBookmarked(2))

        ctrl.bookmarkManager.toggleBookmark(2, for: ctrl.currentPDFURL)
        XCTAssertFalse(ctrl.bookmarkManager.isBookmarked(2))
    }

    // MARK: - Multi-PDF Isolation

    func testMultiplePDFStateIsolation() {
        let doc1 = makeDoc(pageCount: 5)
        let doc2 = makeDoc(pageCount: 5)
        let tmp1 = makeTempURL("iso1")
        let tmp2 = makeTempURL("iso2")

        // Set bookmarks on PDF 1
        ctrl.loadForTesting(document: doc1, url: tmp1)
        ctrl.bookmarkManager.toggleBookmark(1, for: ctrl.currentPDFURL)
        ctrl.bookmarkManager.toggleBookmark(3, for: ctrl.currentPDFURL)

        // Switch to PDF 2, set different bookmarks
        ctrl.loadForTesting(document: doc2, url: tmp2)
        ctrl.bookmarkManager.toggleBookmark(0, for: ctrl.currentPDFURL)
        ctrl.bookmarkManager.toggleBookmark(4, for: ctrl.currentPDFURL)

        // Switch back to PDF 1 — bookmarks should be preserved
        ctrl.loadForTesting(document: doc1, url: tmp1)
        XCTAssertTrue(ctrl.bookmarkManager.isBookmarked(1))
        XCTAssertTrue(ctrl.bookmarkManager.isBookmarked(3))
        XCTAssertFalse(ctrl.bookmarkManager.isBookmarked(0))
        XCTAssertFalse(ctrl.bookmarkManager.isBookmarked(4))
    }

    func testMultiplePDFPageIndexIsolation() {
        let doc1 = makeDoc(pageCount: 10)
        let doc2 = makeDoc(pageCount: 10)
        let tmp1 = makeTempURL("page1")
        let tmp2 = makeTempURL("page2")

        // Navigate to page 7 on PDF 1 and flush
        ctrl.loadForTesting(document: doc1, url: tmp1)
        ctrl.goToPage(7)
        ctrl.flushPendingPersistence()

        // Navigate to page 2 on PDF 2 and flush
        ctrl.loadForTesting(document: doc2, url: tmp2)
        ctrl.goToPage(2)
        ctrl.flushPendingPersistence()

        // Switch back to PDF 1 — should restore page 7
        ctrl.loadForTesting(document: doc1, url: tmp1)
        XCTAssertEqual(ctrl.currentPageIndex, 7)

        // Switch back to PDF 2 — should restore page 2
        ctrl.loadForTesting(document: doc2, url: tmp2)
        XCTAssertEqual(ctrl.currentPageIndex, 2)
    }
}
