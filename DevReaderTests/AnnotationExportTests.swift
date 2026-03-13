import XCTest
import CoreGraphics
@testable import DevReader

final class AnnotationExportTests: XCTestCase {

    // MARK: - Helpers

    private func makeAnnotation(
        pageIndex: Int,
        type: PDFAnnotationData.AnnotationType,
        text: String? = nil,
        colorName: String = "yellow"
    ) -> PDFAnnotationData {
        PDFAnnotationData(
            pageIndex: pageIndex,
            bounds: CodableRect(from: CGRect(x: 0, y: 0, width: 100, height: 20)),
            type: type,
            colorName: colorName,
            text: text
        )
    }

    private func makeNote(
        title: String = "",
        text: String,
        pageIndex: Int,
        chapter: String
    ) -> NoteItem {
        NoteItem(title: title, text: text, pageIndex: pageIndex, chapter: chapter)
    }

    // MARK: - Highlights Export

    func testExportHighlights() {
        let annotations = [
            makeAnnotation(pageIndex: 0, type: .highlight, text: "important concept"),
            makeAnnotation(pageIndex: 2, type: .highlight, text: "another highlight"),
        ]

        let md = AnnotationExportService.generateMarkdown(
            title: "Test PDF",
            annotations: annotations,
            notes: [],
            bookmarks: []
        )

        XCTAssertTrue(md.contains("# Test PDF"))
        XCTAssertTrue(md.contains("## Highlights"))
        XCTAssertTrue(md.contains("**Page 1**: \"important concept\""))
        XCTAssertTrue(md.contains("**Page 3**: \"another highlight\""))
    }

    // MARK: - Underlines Export

    func testExportUnderlines() {
        let annotations = [
            makeAnnotation(pageIndex: 1, type: .underline, text: "underlined text"),
        ]

        let md = AnnotationExportService.generateMarkdown(
            title: "Underline Doc",
            annotations: annotations,
            notes: [],
            bookmarks: []
        )

        XCTAssertTrue(md.contains("## Underlines"))
        XCTAssertTrue(md.contains("**Page 2**: \"underlined text\""))
    }

    // MARK: - Strikethroughs Export

    func testExportStrikethroughs() {
        let annotations = [
            makeAnnotation(pageIndex: 3, type: .strikethrough, text: "deleted text"),
        ]

        let md = AnnotationExportService.generateMarkdown(
            title: "Strike Doc",
            annotations: annotations,
            notes: [],
            bookmarks: []
        )

        XCTAssertTrue(md.contains("## Strikethroughs"))
        XCTAssertTrue(md.contains("**Page 4**: \"deleted text\""))
    }

    // MARK: - Notes Export

    func testExportNotes() {
        let notes = [
            makeNote(title: "Key Idea", text: "This is important", pageIndex: 0, chapter: "Chapter 1"),
            makeNote(text: "Another thought", pageIndex: 4, chapter: "Chapter 2"),
        ]

        let md = AnnotationExportService.generateMarkdown(
            title: "Notes Doc",
            annotations: [],
            notes: notes,
            bookmarks: []
        )

        XCTAssertTrue(md.contains("## Notes"))
        XCTAssertTrue(md.contains("### Chapter 1"))
        XCTAssertTrue(md.contains("Key Idea — This is important"))
        XCTAssertTrue(md.contains("### Chapter 2"))
        XCTAssertTrue(md.contains("**Page 5**: Another thought"))
    }

    // MARK: - Bookmarks Export

    func testExportBookmarks() {
        let bookmarks: Set<Int> = [0, 4, 9]

        let md = AnnotationExportService.generateMarkdown(
            title: "Bookmarks Doc",
            annotations: [],
            notes: [],
            bookmarks: bookmarks
        )

        XCTAssertTrue(md.contains("## Bookmarks"))
        XCTAssertTrue(md.contains("Page 1"))
        XCTAssertTrue(md.contains("Page 5"))
        XCTAssertTrue(md.contains("Page 10"))
    }

    // MARK: - Empty / Minimal Output

    func testExportNoAnnotationsProducesMinimalOutput() {
        let md = AnnotationExportService.generateMarkdown(
            title: "Empty Doc",
            annotations: [],
            notes: [],
            bookmarks: []
        )

        XCTAssertTrue(md.contains("# Empty Doc"))
        XCTAssertTrue(md.contains("_No annotations, notes, or bookmarks found for this document._"))
        XCTAssertFalse(md.contains("## Highlights"))
        XCTAssertFalse(md.contains("## Underlines"))
        XCTAssertFalse(md.contains("## Notes"))
        XCTAssertFalse(md.contains("## Bookmarks"))
    }

    // MARK: - Mixed Content

    func testExportMixedContent() {
        let annotations = [
            makeAnnotation(pageIndex: 0, type: .highlight, text: "highlighted"),
            makeAnnotation(pageIndex: 1, type: .underline, text: "underlined"),
        ]
        let notes = [
            makeNote(title: "Note", text: "Some text", pageIndex: 2, chapter: "Ch 1"),
        ]
        let bookmarks: Set<Int> = [5]

        let md = AnnotationExportService.generateMarkdown(
            title: "Full Doc",
            annotations: annotations,
            notes: notes,
            bookmarks: bookmarks
        )

        XCTAssertTrue(md.contains("## Highlights"))
        XCTAssertTrue(md.contains("## Underlines"))
        XCTAssertTrue(md.contains("## Notes"))
        XCTAssertTrue(md.contains("## Bookmarks"))
        XCTAssertFalse(md.contains("_No annotations"))
    }

    // MARK: - Sorting

    func testHighlightsSortedByPage() {
        let annotations = [
            makeAnnotation(pageIndex: 5, type: .highlight, text: "later"),
            makeAnnotation(pageIndex: 0, type: .highlight, text: "first"),
        ]

        let md = AnnotationExportService.generateMarkdown(
            title: "Sort Test",
            annotations: annotations,
            notes: [],
            bookmarks: []
        )

        let firstRange = md.range(of: "\"first\"")
        let laterRange = md.range(of: "\"later\"")
        XCTAssertNotNil(firstRange)
        XCTAssertNotNil(laterRange)
        XCTAssertTrue(firstRange!.lowerBound < laterRange!.lowerBound, "Highlights should be sorted by page")
    }

    // MARK: - Nil Text Handling

    func testAnnotationWithNilTextShowsPlaceholder() {
        let annotations = [
            makeAnnotation(pageIndex: 0, type: .highlight, text: nil),
        ]

        let md = AnnotationExportService.generateMarkdown(
            title: "Nil Text",
            annotations: annotations,
            notes: [],
            bookmarks: []
        )

        XCTAssertTrue(md.contains("(no text captured)"))
    }

    // MARK: - Header Contains Date

    func testHeaderContainsExportDate() {
        let md = AnnotationExportService.generateMarkdown(
            title: "Date Check",
            annotations: [],
            notes: [],
            bookmarks: []
        )

        XCTAssertTrue(md.contains("_Exported from DevReader on"))
    }
}
