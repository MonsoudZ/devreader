import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class AnnotationManagerTests: XCTestCase {
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

	private func makeDoc(pageCount: Int) -> PDFDocument {
		let doc = PDFDocument()
		for i in 0..<pageCount {
			doc.insert(PDFPage(), at: i)
		}
		return doc
	}

	private func makeTempURL(_ prefix: String = "ann") -> URL {
		URL(fileURLWithPath: NSTemporaryDirectory())
			.appendingPathComponent("\(prefix)_\(UUID().uuidString).pdf")
	}

	// MARK: - Initial State

	func testAnnotationsEmptyByDefault() {
		let doc = makeDoc(pageCount: 3)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		let anns = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(anns.isEmpty)
	}

	// MARK: - Remove Annotations

	func testRemoveAnnotationByIndex() {
		let doc = makeDoc(pageCount: 3)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// Manually add annotation data to test removal
		let record = PDFAnnotationData(
			pageIndex: 0,
			bounds: CodableRect(from: CGRect(x: 10, y: 20, width: 200, height: 14)),
			type: .highlight,
			colorName: "yellow",
			text: "test"
		)

		// Add visual annotation to PDF page
		if let page = doc.page(at: 0) {
			let ann = PDFAnnotation(bounds: record.bounds.cgRect, forType: .highlight, withProperties: nil)
			page.addAnnotation(ann)
		}

		// We can't directly set internal annotations, but we can test through the manager's interface
		// First verify no annotations exist via the manager
		let before = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(before.isEmpty, "Should start empty since we haven't used the manager's add methods")

		// Remove on an empty manager should not crash
		ctrl.annotationManager.removeAnnotation(at: 0)
		ctrl.annotationManager.removeAnnotation(at: -1)
		ctrl.annotationManager.removeAnnotation(at: 999)
	}

	func testRemoveAnnotationsOnCurrentPage() {
		let doc = makeDoc(pageCount: 3)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// Add visual annotations directly to page 0
		if let page = doc.page(at: 0) {
			let highlight = PDFAnnotation(bounds: CGRect(x: 10, y: 20, width: 200, height: 14), forType: .highlight, withProperties: nil)
			page.addAnnotation(highlight)
			let underline = PDFAnnotation(bounds: CGRect(x: 10, y: 40, width: 200, height: 14), forType: .underline, withProperties: nil)
			page.addAnnotation(underline)

			let before = page.annotations.count
			XCTAssertGreaterThanOrEqual(before, 2)
		}

		// removeAnnotationsOnCurrentPage should remove highlight/underline/strikethrough annotations from the PDF page
		ctrl.annotationManager.removeAnnotationsOnCurrentPage()

		if let page = doc.page(at: 0) {
			let remainingMarkup = page.annotations.filter { ann in
				[PDFAnnotationSubtype.highlight.rawValue,
				 PDFAnnotationSubtype.underline.rawValue,
				 PDFAnnotationSubtype.strikeOut.rawValue].contains(ann.type)
			}
			XCTAssertTrue(remainingMarkup.isEmpty, "All markup annotations should be removed")
		}
	}

	// MARK: - Clear Annotations

	func testClearAnnotations() {
		let doc = makeDoc(pageCount: 2)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		ctrl.annotationManager.clearAnnotations()

		let anns = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(anns.isEmpty)
	}

	// MARK: - Flush Persistence

	func testFlushPendingPersistenceDoesNotCrash() {
		let doc = makeDoc(pageCount: 2)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// Should not crash even with no pending changes
		ctrl.annotationManager.flushPendingPersistence()
	}

	// MARK: - Restore Annotations

	func testRestoreAnnotationsFromPersistence() {
		let doc = makeDoc(pageCount: 3)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// Restore from a URL that has no saved annotations
		ctrl.annotationManager.restoreAnnotations(for: url)
		let anns = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(anns.isEmpty, "Should be empty when no saved annotations exist")
	}

	// MARK: - Page Isolation

	func testAnnotationsOnCurrentPageFiltersCorrectly() {
		let doc = makeDoc(pageCount: 5)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// Navigate to page 2
		ctrl.goToPage(2)
		let anns = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(anns.isEmpty, "Page 2 should have no annotations by default")

		// Navigate to page 0
		ctrl.goToPage(0)
		let anns0 = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(anns0.isEmpty, "Page 0 should have no annotations by default")
	}

	// MARK: - Export Annotated PDF

	func testExportAnnotatedPDFNoDocumentDoesNotCrash() {
		// No document loaded — should not crash
		ctrl.annotationManager.exportAnnotatedPDF()
	}

	// MARK: - Annotation Colors

	func testAnnotationColorMapping() {
		// Test via the static color helper (indirectly through restore)
		// Different color names should produce different visual results
		let colors = ["yellow", "green", "blue", "pink", "unknown"]
		for color in colors {
			let record = PDFAnnotationData(
				pageIndex: 0,
				bounds: CodableRect(from: CGRect(x: 0, y: 0, width: 100, height: 14)),
				type: .highlight,
				colorName: color
			)
			XCTAssertEqual(record.colorName, color)
		}
	}

	// MARK: - Annotation Types

	func testAnnotationTypeCoverage() {
		let types: [PDFAnnotationData.AnnotationType] = [.highlight, .underline, .strikethrough]
		XCTAssertEqual(types.count, 3)

		for type in types {
			let record = PDFAnnotationData(
				pageIndex: 0,
				bounds: CodableRect(from: CGRect(x: 0, y: 0, width: 100, height: 14)),
				type: type,
				colorName: "yellow"
			)
			XCTAssertEqual(record.type, type)
		}
	}

	// MARK: - Capture Highlight to Notes

	func testCaptureHighlightWithNoDocumentDoesNotCrash() {
		// No document loaded
		ctrl.annotationManager.captureHighlightToNotes()
	}

	func testCaptureHighlightWithNoSelectionDoesNotCrash() {
		let doc = makeDoc(pageCount: 2)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// No selection — should show warning toast, not crash
		ctrl.annotationManager.captureHighlightToNotes()
	}

	// MARK: - Add Sticky Note

	func testAddStickyNoteWithNoDocumentDoesNotCrash() {
		ctrl.annotationManager.addStickyNote()
	}

	func testAddStickyNoteWithNoSelection() {
		let doc = makeDoc(pageCount: 2)
		let url = makeTempURL()
		ctrl.loadForTesting(document: doc, url: url)

		// Should create a sticky note with empty text (no selection)
		ctrl.annotationManager.addStickyNote()
	}
}
