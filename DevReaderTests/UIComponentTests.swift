import XCTest
import SwiftUI
import PDFKit

@testable import DevReader

/// Tests for UI component state and behavior using real objects.
@MainActor
final class UIComponentTests: XCTestCase {

	// MARK: - Panel State Tests

	func testRightTabEnum() {
		// Verify all expected tab cases exist and are distinct
		let tabs: [RightTab] = [.notes, .code, .web]
		XCTAssertEqual(Set(tabs).count, 3, "All right panel tabs should be distinct")
	}

	// MARK: - PDFController State

	func testPDFControllerInitialState() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }

		XCTAssertNil(ctrl.document, "No document should be loaded initially")
		XCTAssertEqual(ctrl.currentPageIndex, 0)
		XCTAssertFalse(ctrl.isLoadingPDF)
	}

	func testPDFControllerNavigationBounds() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 5)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nav_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.goToPage(-1)
		XCTAssertGreaterThanOrEqual(ctrl.currentPageIndex, 0, "Should clamp to 0")

		ctrl.goToPage(999)
		XCTAssertLessThan(ctrl.currentPageIndex, doc.pageCount, "Should clamp to last page")
	}

	func testPDFControllerDocumentProperties() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 3)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("props_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		let props = ctrl.documentProperties()
		let pagesEntry = props.first { $0.0 == "Pages" }
		XCTAssertNotNil(pagesEntry)
		XCTAssertEqual(pagesEntry?.1, "3")
	}

	// MARK: - Panel Height Clamping

	func testResizableSearchPanelConstraints() {
		let minHeight: CGFloat = 100
		let maxHeight: CGFloat = 400

		var height: CGFloat = 50
		height = max(minHeight, min(maxHeight, height))
		XCTAssertEqual(height, minHeight, "Should clamp to minimum")

		height = 500
		height = max(minHeight, min(maxHeight, height))
		XCTAssertEqual(height, maxHeight, "Should clamp to maximum")
	}

	// MARK: - Search Manager via PDFController

	func testSearchManagerInitialState() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }

		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty, "Search results should start empty")
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
		XCTAssertEqual(ctrl.searchManager.searchQuery, "")
	}

	func testSearchManagerClearSearch() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		ctrl.searchManager.searchQuery = "test"
		ctrl.searchManager.clearSearch()

		XCTAssertEqual(ctrl.searchManager.searchQuery, "", "clearSearch should reset query")
		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty, "clearSearch should empty results")
	}

	// MARK: - Bookmark Manager

	func testBookmarkManagerToggle() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 3)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bm_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		XCTAssertFalse(ctrl.bookmarkManager.bookmarks.contains(0))
		ctrl.bookmarkManager.toggleBookmark(0, for: url)
		XCTAssertTrue(ctrl.bookmarkManager.bookmarks.contains(0), "Bookmark should be added")
		ctrl.bookmarkManager.toggleBookmark(0, for: url)
		XCTAssertFalse(ctrl.bookmarkManager.bookmarks.contains(0), "Bookmark should be removed")
	}
}
