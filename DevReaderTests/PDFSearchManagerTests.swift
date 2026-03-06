import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class PDFSearchManagerTests: XCTestCase {
	private var ctrl: PDFController!

	override func setUp() {
		super.setUp()
		ctrl = PDFController()
	}

	override func tearDown() {
		ctrl = nil
		let dataDir = JSONStorageService.dataDirectory
		try? FileManager.default.removeItem(at: dataDir)
		JSONStorageService.ensureDirectories()
		super.tearDown()
	}

	// MARK: - Helpers

	private func makeDocWithText(_ texts: [String]) -> (PDFDocument, URL) {
		let doc = PDFDocument()
		for (i, text) in texts.enumerated() {
			let page = PDFPage()
			// Draw text onto the page so findString works
			let renderer = CGContext(
				consumer: CGDataConsumer(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmp_\(UUID()).pdf") as CFURL)!,
				mediaBox: nil,
				nil
			)
			// Use a simpler approach: create a PDF with text content
			let data = NSMutableData()
			let consumer = CGDataConsumer(data: data as CFMutableData)!
			var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
			let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
			ctx.beginPage(mediaBox: &mediaBox)
			let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: font,
				.foregroundColor: CGColor(gray: 0, alpha: 1)
			]
			let attrStr = NSAttributedString(string: text, attributes: attrs)
			let line = CTLineCreateWithAttributedString(attrStr)
			ctx.textPosition = CGPoint(x: 72, y: 700)
			CTLineDraw(line, ctx)
			ctx.endPage()
			ctx.closePDF()

			if let pdfDoc = PDFDocument(data: data as Data), let pdfPage = pdfDoc.page(at: 0) {
				doc.insert(pdfPage, at: i)
			} else {
				doc.insert(PDFPage(), at: i)
			}
			_ = renderer
		}
		let url = URL(fileURLWithPath: NSTemporaryDirectory())
			.appendingPathComponent("search_\(UUID()).pdf")
		return (doc, url)
	}

	private func makeBlankDoc(pageCount: Int) -> (PDFDocument, URL) {
		let doc = PDFDocument()
		for i in 0..<pageCount {
			doc.insert(PDFPage(), at: i)
		}
		let url = URL(fileURLWithPath: NSTemporaryDirectory())
			.appendingPathComponent("blank_\(UUID()).pdf")
		return (doc, url)
	}

	// MARK: - Initial State

	func testInitialState() {
		let sm = ctrl.searchManager
		XCTAssertEqual(sm.searchQuery, "")
		XCTAssertTrue(sm.searchResults.isEmpty)
		XCTAssertEqual(sm.searchIndex, 0)
		XCTAssertFalse(sm.isSearching)
	}

	// MARK: - performSearch

	func testSearchWithNilDocument() {
		ctrl.searchManager.performSearch("hello", in: nil)
		// Should no-op without crash
		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
	}

	func testSearchEmptyQuery() {
		let (doc, url) = makeBlankDoc(pageCount: 3)
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.searchQuery = "old"
		ctrl.searchManager.performSearch("", in: doc)
		XCTAssertEqual(ctrl.searchManager.searchQuery, "")
		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
	}

	func testSearchWhitespaceOnlyQuery() {
		let (doc, url) = makeBlankDoc(pageCount: 2)
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("   \t  ", in: doc)
		XCTAssertEqual(ctrl.searchManager.searchQuery, "")
		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
	}

	func testSearchFindsText() async {
		let (doc, url) = makeDocWithText(["Hello World", "Goodbye World", "Hello Again"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)

		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		// Should find at least one result (pages with "Hello")
		XCTAssertGreaterThanOrEqual(ctrl.searchManager.searchResults.count, 1)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
	}

	func testSearchCaseInsensitive() async {
		let (doc, url) = makeDocWithText(["Hello World"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("hello", in: doc)

		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		// Case insensitive should still find "Hello"
		XCTAssertGreaterThanOrEqual(ctrl.searchManager.searchResults.count, 1)
	}

	func testSearchNoResults() async {
		let (doc, url) = makeDocWithText(["Hello World"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("ZZZZNOTFOUND", in: doc)

		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
	}

	func testSearchSetsHighlightColor() async {
		let (doc, url) = makeDocWithText(["Hello World Hello"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)

		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		for sel in ctrl.searchManager.searchResults {
			XCTAssertNotNil(sel.color, "Search results should have highlight color set")
		}
	}

	// MARK: - Navigation

	func testNextSearchResultWraps() async {
		let (doc, url) = makeDocWithText(["Hello Hello Hello"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)
		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		guard ctrl.searchManager.searchResults.count >= 2 else {
			// Skip if PDF text rendering didn't produce multiple results
			return
		}

		let count = ctrl.searchManager.searchResults.count
		// Navigate to last
		for _ in 0..<count - 1 {
			ctrl.searchManager.nextSearchResult(in: doc)
		}
		XCTAssertEqual(ctrl.searchManager.searchIndex, count - 1)

		// Next should wrap to 0
		ctrl.searchManager.nextSearchResult(in: doc)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
	}

	func testPreviousSearchResultWraps() async {
		let (doc, url) = makeDocWithText(["Hello Hello Hello"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)
		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		guard ctrl.searchManager.searchResults.count >= 2 else { return }

		let count = ctrl.searchManager.searchResults.count
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)

		// Previous from 0 should wrap to last
		ctrl.searchManager.previousSearchResult(in: doc)
		XCTAssertEqual(ctrl.searchManager.searchIndex, count - 1)
	}

	func testNextPreviousNoOpWhenEmpty() {
		let (doc, url) = makeBlankDoc(pageCount: 2)
		ctrl.loadForTesting(document: doc, url: url)

		// No results — should not crash
		ctrl.searchManager.nextSearchResult(in: doc)
		ctrl.searchManager.previousSearchResult(in: doc)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
	}

	// MARK: - jumpToSearchResult

	func testJumpToSearchResult() async {
		let (doc, url) = makeDocWithText(["Hello Hello Hello Hello Hello"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)
		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		guard ctrl.searchManager.searchResults.count >= 3 else { return }

		ctrl.searchManager.jumpToSearchResult(2, in: doc)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 2)
	}

	func testJumpToSearchResultWrapsNegative() async {
		let (doc, url) = makeDocWithText(["Hello Hello Hello"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)
		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		guard ctrl.searchManager.searchResults.count >= 2 else { return }

		let count = ctrl.searchManager.searchResults.count
		ctrl.searchManager.jumpToSearchResult(-1, in: doc)
		XCTAssertEqual(ctrl.searchManager.searchIndex, count - 1)
	}

	func testJumpNoOpWhenEmpty() {
		let (doc, url) = makeBlankDoc(pageCount: 1)
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.jumpToSearchResult(5, in: doc)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
	}

	// MARK: - clearSearch

	func testClearSearchResetsAll() async {
		let (doc, url) = makeDocWithText(["Hello World"])
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("Hello", in: doc)
		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		ctrl.searchManager.clearSearch()

		XCTAssertEqual(ctrl.searchManager.searchQuery, "")
		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
		XCTAssertEqual(ctrl.searchManager.searchIndex, 0)
	}

	// MARK: - focusCurrentSearchSelection

	func testFocusReturnsNilWhenEmpty() {
		let (doc, url) = makeBlankDoc(pageCount: 2)
		ctrl.loadForTesting(document: doc, url: url)

		let pageIndex = ctrl.searchManager.focusCurrentSearchSelection(in: doc)
		XCTAssertNil(pageIndex)
	}

	// MARK: - Search Cancellation

	func testNewSearchCancelsPrevious() async {
		let (doc, url) = makeDocWithText(["Hello World Goodbye"])
		ctrl.loadForTesting(document: doc, url: url)

		// Start first search
		ctrl.searchManager.performSearch("Hello", in: doc)
		// Immediately start second search (should cancel first)
		ctrl.searchManager.performSearch("Goodbye", in: doc)

		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		XCTAssertEqual(ctrl.searchManager.searchQuery, "Goodbye")
	}

	// MARK: - Search on Blank Pages

	func testSearchOnBlankPagesFindsNothing() async {
		let (doc, url) = makeBlankDoc(pageCount: 5)
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.searchManager.performSearch("anything", in: doc)
		await waitUntil(timeout: 5.0) { !ctrl.searchManager.isSearching }

		XCTAssertTrue(ctrl.searchManager.searchResults.isEmpty)
	}
}
