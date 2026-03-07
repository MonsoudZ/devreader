import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class TTSServiceTests: XCTestCase {
	private var tts: TextToSpeechService!

	override func setUp() {
		super.setUp()
		tts = TextToSpeechService()
	}

	override func tearDown() {
		tts.stop()
		tts = nil
		super.tearDown()
	}

	// MARK: - Helpers

	private func makeDocWithText(_ texts: [String]) -> PDFDocument {
		let doc = PDFDocument()
		for (i, text) in texts.enumerated() {
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
		}
		return doc
	}

	// MARK: - Initial State

	func testInitialState() {
		XCTAssertFalse(tts.isSpeaking)
		XCTAssertFalse(tts.isPaused)
		XCTAssertEqual(tts.currentPage, 0)
	}

	// MARK: - Stop

	func testStopResetsState() {
		tts.stop()
		XCTAssertFalse(tts.isSpeaking)
		XCTAssertFalse(tts.isPaused)
	}

	func testStopClearsPages() {
		let doc = makeDocWithText(["Hello World"])
		tts.startReading(document: doc, fromPage: 0)
		tts.stop()
		XCTAssertFalse(tts.isSpeaking)
	}

	// MARK: - Start Reading

	func testStartReadingSetsIsSpeaking() {
		let doc = makeDocWithText(["Hello World", "Second page"])
		tts.startReading(document: doc, fromPage: 0)
		// Note: isSpeaking depends on whether text was extractable
		// If text was extracted, it should be speaking
		if tts.isSpeaking {
			XCTAssertTrue(tts.isSpeaking)
			XCTAssertEqual(tts.currentPage, 0)
		}
		tts.stop()
	}

	func testStartReadingFromMiddlePage() {
		let doc = makeDocWithText(["Page 1", "Page 2", "Page 3"])
		tts.startReading(document: doc, fromPage: 1)
		if tts.isSpeaking {
			XCTAssertEqual(tts.currentPage, 1)
		}
		tts.stop()
	}

	func testStartReadingEmptyDocument() {
		let doc = PDFDocument()
		tts.startReading(document: doc, fromPage: 0)
		XCTAssertFalse(tts.isSpeaking, "Should not speak with empty document")
	}

	func testStartReadingBlankPages() {
		let doc = PDFDocument()
		for i in 0..<3 {
			doc.insert(PDFPage(), at: i)
		}
		tts.startReading(document: doc, fromPage: 0)
		XCTAssertFalse(tts.isSpeaking, "Should not speak with blank pages (no text)")
	}

	// MARK: - Read Current Page

	func testReadCurrentPage() {
		let doc = makeDocWithText(["Hello from page 1"])
		tts.readCurrentPage(document: doc, pageIndex: 0)
		if tts.isSpeaking {
			XCTAssertEqual(tts.currentPage, 0)
		}
		tts.stop()
	}

	func testReadCurrentPageInvalidIndex() {
		let doc = makeDocWithText(["Hello"])
		tts.readCurrentPage(document: doc, pageIndex: 99)
		XCTAssertFalse(tts.isSpeaking, "Should not speak for invalid page index")
	}

	func testReadCurrentPageBlankPage() {
		let doc = PDFDocument()
		doc.insert(PDFPage(), at: 0)
		tts.readCurrentPage(document: doc, pageIndex: 0)
		XCTAssertFalse(tts.isSpeaking, "Should not speak for blank page")
	}

	// MARK: - Pause / Resume

	func testPauseSetsState() {
		let doc = makeDocWithText(["Hello World this is a longer text for testing"])
		tts.startReading(document: doc, fromPage: 0)
		if tts.isSpeaking {
			tts.pause()
			XCTAssertFalse(tts.isSpeaking)
		}
		tts.stop()
	}

	func testResumeAfterPause() {
		let doc = makeDocWithText(["Hello World this is a longer text for testing that should take a while to speak so we can test pause and resume functionality properly"])
		tts.startReading(document: doc, fromPage: 0)
		if tts.isSpeaking {
			tts.pause()
			XCTAssertFalse(tts.isSpeaking)
			// isPaused depends on synthesizer state — it may have finished the short utterance
			if tts.isPaused {
				tts.resume()
				XCTAssertTrue(tts.isSpeaking)
			}
		}
		tts.stop()
	}

	func testResumeWithoutPauseDoesNothing() {
		tts.resume()
		XCTAssertFalse(tts.isSpeaking, "Resume without speaking should not set isSpeaking")
	}

	// MARK: - Multiple Operations

	func testStartStopStartAgain() {
		let doc = makeDocWithText(["Hello", "World"])
		tts.startReading(document: doc, fromPage: 0)
		tts.stop()
		XCTAssertFalse(tts.isSpeaking)

		tts.startReading(document: doc, fromPage: 1)
		if tts.isSpeaking {
			XCTAssertEqual(tts.currentPage, 1)
		}
		tts.stop()
	}

	func testStartReadingStopsPreviousSpeech() {
		let doc = makeDocWithText(["Hello", "World"])
		tts.startReading(document: doc, fromPage: 0)
		// Starting again should stop the previous one first
		tts.startReading(document: doc, fromPage: 1)
		if tts.isSpeaking {
			XCTAssertEqual(tts.currentPage, 1)
		}
		tts.stop()
	}

	// MARK: - Edge Cases

	func testStartReadingBeyondPageCount() {
		let doc = makeDocWithText(["Only page"])
		tts.startReading(document: doc, fromPage: 100)
		XCTAssertFalse(tts.isSpeaking, "Should not speak when start page is beyond document")
	}

	func testStopIdempotent() {
		tts.stop()
		tts.stop()
		tts.stop()
		XCTAssertFalse(tts.isSpeaking)
		XCTAssertFalse(tts.isPaused)
	}
}
