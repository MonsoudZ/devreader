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
        // Clear all DevReader keys to prevent test interference
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("DevReader.") {
            defaults.removeObject(forKey: key)
        }
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
        ctrl.toggleBookmark(0)
        XCTAssertTrue(ctrl.isBookmarked(0))

        ctrl.loadForTesting(document: doc, url: tmp)
        XCTAssertTrue(ctrl.isBookmarked(0))
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
        ctrl.searchQuery = "test"
        ctrl.searchIndex = 2

        ctrl.clearSearch()
        XCTAssertEqual(ctrl.searchQuery, "")
        XCTAssertTrue(ctrl.searchResults.isEmpty)
        XCTAssertEqual(ctrl.searchIndex, 0)
    }

    func testSearchEmptyQueryClearsResults() {
        let doc = makeDoc(pageCount: 3)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        // Search with whitespace-only query should clear
        ctrl.performSearch("   ")
        XCTAssertTrue(ctrl.searchResults.isEmpty)
        XCTAssertEqual(ctrl.searchQuery, "")
    }

    func testSearchNoOpsWhenEmpty() {
        let doc = makeDoc(pageCount: 3)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        // No results — next/prev/jump should not crash
        XCTAssertTrue(ctrl.searchResults.isEmpty)
        ctrl.nextSearchResult()
        ctrl.previousSearchResult()
        ctrl.jumpToSearchResult(5)
        XCTAssertEqual(ctrl.searchIndex, 0)
    }

    // MARK: - Recents

    func testAddRecentAddsToList() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.addRecent(tmp)
        XCTAssertTrue(ctrl.recentDocuments.contains(tmp))
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
            ctrl.addRecent(url)
        }

        XCTAssertLessThanOrEqual(ctrl.recentDocuments.count, 10)
    }

    func testAddRecentNoDuplicates() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.addRecent(tmp)
        ctrl.addRecent(tmp)
        ctrl.addRecent(tmp)

        let occurrences = ctrl.recentDocuments.filter { $0 == tmp }.count
        XCTAssertEqual(occurrences, 1)
    }

    // MARK: - Pinning

    func testPinAndUnpin() {
        let doc = makeDoc(pageCount: 1)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.addRecent(tmp)
        XCTAssertTrue(ctrl.recentDocuments.contains(tmp))

        ctrl.pin(tmp)
        XCTAssertTrue(ctrl.isPinned(tmp))
        XCTAssertTrue(ctrl.pinnedDocuments.contains(tmp))
        XCTAssertFalse(ctrl.recentDocuments.contains(tmp))

        ctrl.unpin(tmp)
        XCTAssertFalse(ctrl.isPinned(tmp))
        XCTAssertTrue(ctrl.recentDocuments.contains(tmp))
    }

    func testPinnedReducesRecentsCap() {
        let doc = makeDoc(pageCount: 1)
        let baseURL = makeTempURL()
        ctrl.loadForTesting(document: doc, url: baseURL)

        // Pin 3 URLs
        for i in 0..<3 {
            ctrl.pin(makeTempURL("pin\(i)"))
        }

        // Add 10 recents — cap should be 10 - 3 = 7
        for i in 0..<10 {
            ctrl.addRecent(makeTempURL("r\(i)"))
        }

        XCTAssertLessThanOrEqual(ctrl.recentDocuments.count, 7)
    }

    // MARK: - Clear Session

    func testClearSessionResetsAllState() {
        let doc = makeDoc(pageCount: 5)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        ctrl.goToPage(3)
        ctrl.toggleBookmark(2)
        ctrl.searchQuery = "test"

        ctrl.clearSession()

        XCTAssertNil(ctrl.document)
        XCTAssertEqual(ctrl.currentPageIndex, 0)
        XCTAssertTrue(ctrl.bookmarks.isEmpty)
        XCTAssertEqual(ctrl.searchQuery, "")
        XCTAssertTrue(ctrl.searchResults.isEmpty)
    }

    // MARK: - Bookmarks

    func testBookmarkToggle() {
        let doc = makeDoc(pageCount: 5)
        let tmp = makeTempURL()
        ctrl.loadForTesting(document: doc, url: tmp)

        XCTAssertFalse(ctrl.isBookmarked(2))

        ctrl.toggleBookmark(2)
        XCTAssertTrue(ctrl.isBookmarked(2))

        ctrl.toggleBookmark(2)
        XCTAssertFalse(ctrl.isBookmarked(2))
    }

    // MARK: - Multi-PDF Isolation

    func testMultiplePDFStateIsolation() {
        let doc1 = makeDoc(pageCount: 5)
        let doc2 = makeDoc(pageCount: 5)
        let tmp1 = makeTempURL("iso1")
        let tmp2 = makeTempURL("iso2")

        // Set bookmarks on PDF 1
        ctrl.loadForTesting(document: doc1, url: tmp1)
        ctrl.toggleBookmark(1)
        ctrl.toggleBookmark(3)

        // Switch to PDF 2, set different bookmarks
        ctrl.loadForTesting(document: doc2, url: tmp2)
        ctrl.toggleBookmark(0)
        ctrl.toggleBookmark(4)

        // Switch back to PDF 1 — bookmarks should be preserved
        ctrl.loadForTesting(document: doc1, url: tmp1)
        XCTAssertTrue(ctrl.isBookmarked(1))
        XCTAssertTrue(ctrl.isBookmarked(3))
        XCTAssertFalse(ctrl.isBookmarked(0))
        XCTAssertFalse(ctrl.isBookmarked(4))
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
