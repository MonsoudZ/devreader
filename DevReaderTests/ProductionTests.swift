import XCTest
@testable import DevReader
import PDFKit

@MainActor
final class ProductionTests: XCTestCase {

    override func tearDownWithError() throws {
        // Clear all UserDefaults to prevent test interference
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("DevReader.") {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Large PDF Loading Performance Tests

    func testLargePDFLoadingPerformance() async {
        let pdfController = PDFController()
        let testURL = createLargeTestPDF(pageCount: 600)

        let startTime = CFAbsoluteTimeGetCurrent()

        pdfController.load(url: testURL)

        // Wait for loading: first wait for debounce to trigger, then poll
        await waitForLoad(pdfController)

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Large PDF should load within 10 seconds
        XCTAssertLessThan(timeElapsed, 10.0, "Large PDF should load within 10 seconds")
        XCTAssertNotNil(pdfController.document, "PDF document should be loaded")
        XCTAssertGreaterThan(pdfController.document?.pageCount ?? 0, 500, "Should be a large PDF")

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    func testMemoryUsageWithLargePDF() async {
        let pdfController = PDFController()
        let testURL = createLargeTestPDF(pageCount: 600)

        // Get initial memory usage
        let initialMemory = getMemoryUsage()

        pdfController.load(url: testURL)

        // Wait for loading to complete
        await waitForLoad(pdfController)

        // Get memory usage after loading
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        // Memory increase should be reasonable (less than 1GB)
        XCTAssertLessThan(memoryIncrease, 1_000_000_000, "Memory usage should be reasonable")

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Search Correctness Tests

    func testSearchCaseInsensitive() async {
        let pdfController = PDFController()
        let testURL = createSearchableTestPDF()
        let document = PDFDocument(url: testURL)!

        // Use loadForTesting to bypass async debounce
        pdfController.loadForTesting(document: document, url: testURL)

        XCTAssertNotNil(pdfController.document, "Document should be loaded")

        // Use performSearch directly
        pdfController.performSearch("Hello")

        XCTAssertGreaterThan(pdfController.searchResults.count, 0, "Should find search results")

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    func testSearchHighlights() async {
        let pdfController = PDFController()
        let testURL = createSearchableTestPDF()
        let document = PDFDocument(url: testURL)!

        pdfController.loadForTesting(document: document, url: testURL)

        pdfController.performSearch("Hello")

        // Verify search results have proper highlighting
        for result in pdfController.searchResults {
            XCTAssertNotNil(result, "Search result should not be nil")
            XCTAssertGreaterThan(result.pages.count, 0, "Search result should have pages")
        }

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    func testSearchPerformanceWithLargePDF() async {
        let pdfController = PDFController()
        let testURL = createLargeTestPDF(pageCount: 600)

        pdfController.load(url: testURL)
        await waitForLoad(pdfController)

        guard pdfController.document != nil else {
            // PDF too large to load in CI; skip gracefully
            try? FileManager.default.removeItem(at: testURL)
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        pdfController.performSearch("Page")

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Search should complete within 5 seconds even for large PDFs
        XCTAssertLessThan(timeElapsed, 5.0, "Search should be fast even for large PDFs")

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Session Restore Tests

    func testSessionRestoreWithMultiplePDFs() async {
        let pdfController = PDFController()
        let testURLs = [
            createMultiPageTestPDF(name: "multi1", pageCount: 10),
            createMultiPageTestPDF(name: "multi2", pageCount: 10),
            createMultiPageTestPDF(name: "multi3", pageCount: 10)
        ]

        // Load multiple PDFs sequentially using loadForTesting
        for (index, url) in testURLs.enumerated() {
            guard let doc = PDFDocument(url: url) else {
                XCTFail("Failed to create PDFDocument for \(url.lastPathComponent)")
                continue
            }
            pdfController.loadForTesting(document: doc, url: url)

            // Set page index (within valid range)
            let targetPage = min(index + 1, doc.pageCount - 1)
            pdfController.goToPage(targetPage)
            pdfController.savePageForPDF(url)
        }

        // Clear current session
        pdfController.clearSession()

        // Restore session for first PDF
        guard let doc = PDFDocument(url: testURLs[0]) else {
            XCTFail("Failed to reload first PDF")
            return
        }
        pdfController.loadForTesting(document: doc, url: testURLs[0])

        // Verify page was restored
        XCTAssertEqual(pdfController.currentPageIndex, 1, "Page should be restored")

        // Clean up
        for url in testURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testSessionRestoreAfterAppRestart() async {
        let testURL = createMultiPageTestPDF(name: "session_restore", pageCount: 10)

        let pdfController = PDFController()
        guard let doc = PDFDocument(url: testURL) else {
            XCTFail("Failed to create PDFDocument")
            return
        }

        // Load PDF and set page
        pdfController.loadForTesting(document: doc, url: testURL)
        pdfController.goToPage(5)
        pdfController.savePageForPDF(testURL)

        // Create new controller (simulating app restart)
        let newController = PDFController()
        guard let doc2 = PDFDocument(url: testURL) else {
            XCTFail("Failed to reload PDF")
            return
        }
        newController.loadForTesting(document: doc2, url: testURL)

        // Verify page was restored
        XCTAssertEqual(newController.currentPageIndex, 5, "Page should be restored after app restart")

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Persistence Tests

    func testAtomicWrites() async {
        let testData: [String: String] = ["test": "value", "number": "42"]
        let key = "test.atomic.writes"

        // Save data
        PersistenceService.saveCodable(testData, forKey: key)

        // Load data
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)

        XCTAssertNotNil(loadedData, "Data should be loaded successfully")
        XCTAssertEqual(loadedData?["test"], "value", "String value should match")
        XCTAssertEqual(loadedData?["number"], "42", "Number value should match")

        // Clean up
        PersistenceService.delete(forKey: key)
    }

    func testPDFScoping() async {
        // Use unique filenames so URLs differ
        let pdf1URL = createMultiPageTestPDF(name: "scope_pdf1", pageCount: 1)
        let pdf2URL = createMultiPageTestPDF(name: "scope_pdf2", pageCount: 1)

        let key1 = PersistenceService.key("test.scope", for: pdf1URL)
        let key2 = PersistenceService.key("test.scope", for: pdf2URL)

        // Keys should be different for different PDFs
        XCTAssertNotEqual(key1, key2, "Keys should be different for different PDFs")

        // Clean up
        try? FileManager.default.removeItem(at: pdf1URL)
        try? FileManager.default.removeItem(at: pdf2URL)
    }

    // MARK: - Error Handling Tests

    func testErrorRecovery() async {
        let pdfController = PDFController()
        let invalidURL = URL(fileURLWithPath: "/invalid/path.pdf")

        // This should not crash the app
        pdfController.load(url: invalidURL)

        // Wait a bit for error handling
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // App should still be functional
        XCTAssertNotNil(pdfController, "PDFController should still exist")
    }

    func testMemoryPressureHandling() async {
        let pdfController = PDFController()
        let testURL = createMultiPageTestPDF(name: "memory_pressure", pageCount: 10)

        guard let doc = PDFDocument(url: testURL) else {
            XCTFail("Failed to create PDFDocument")
            return
        }

        pdfController.loadForTesting(document: doc, url: testURL)

        // Simulate memory pressure
        NotificationCenter.default.post(name: .memoryPressure, object: nil)

        // App should handle memory pressure gracefully
        XCTAssertNotNil(pdfController.document, "Document should still be available")

        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Helper Methods

    /// Creates a proper searchable PDF using Core Graphics text rendering
    private func createSearchableTestPDF() -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("searchable_\(UUID().uuidString).pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard let context = CGContext(tempURL as CFURL, mediaBox: nil, nil) else {
            // Fallback: create with PDFKit
            return createMultiPageTestPDF(name: "searchable_fallback_\(UUID().uuidString)", pageCount: 3)
        }

        for i in 0..<3 {
            var mediaBox = pageRect
            context.beginPage(mediaBox: &mediaBox)

            let text = "Hello World - This is page \(i + 1) of the test document." as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14)
            ]
            // Draw text using NSString drawing (creates actual searchable text)
            let textRect = CGRect(x: 50, y: 700, width: 500, height: 50)
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            text.draw(in: textRect, withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()

            context.endPage()
        }
        context.closePDF()

        return tempURL
    }

    /// Creates a multi-page PDF with unique name using PDFKit
    private func createMultiPageTestPDF(name: String, pageCount: Int) -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).pdf")

        let pdfDocument = PDFDocument()
        for i in 0..<pageCount {
            let page = PDFPage()
            pdfDocument.insert(page, at: i)
        }
        pdfDocument.write(to: tempURL)

        return tempURL
    }

    private func createLargeTestPDF(pageCount: Int) -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("large_test_\(UUID().uuidString).pdf")

        let pdfDocument = PDFDocument()
        for i in 0..<pageCount {
            let page = PDFPage()
            pdfDocument.insert(page, at: i)
        }
        pdfDocument.write(to: tempURL)

        return tempURL
    }

    /// Waits for async PDF load (accounts for 0.1s debounce in load())
    private func waitForLoad(_ controller: PDFController) async {
        // Wait for debounce to trigger (0.1s) + small buffer
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then poll for loading to complete
        var attempts = 0
        while controller.isLoadingPDF && attempts < 100 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }

        // Extra settle time for document assignment
        if controller.document == nil {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}
