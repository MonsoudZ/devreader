import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class LargePDFTests: XCTestCase {

    private var pdfController: PDFController!
    private var performanceMonitor: PerformanceMonitor!

    override func setUp() {
        super.setUp()
        pdfController = PDFController()
        performanceMonitor = PerformanceMonitor.shared
    }

    override func tearDown() {
        pdfController = nil
        performanceMonitor = nil
        super.tearDown()
    }

    // MARK: - Large PDF Test Data Creation

    func testCreateLargePDF() throws {
        let largePDFURL = createTestLargePDF(pageCount: 750)

        XCTAssertNotNil(largePDFURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: largePDFURL?.path ?? ""))

        if let url = largePDFURL, let document = PDFDocument(url: url) {
            XCTAssertGreaterThanOrEqual(document.pageCount, 750)
        } else {
            XCTFail("Failed to create large test PDF")
        }

        if let url = largePDFURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - PDF Loading Performance Tests

    func testLargePDFLoadingPerformance() async throws {
        guard let testPDF = createTestLargePDF(pageCount: 500) else {
            throw XCTSkip("Could not create test PDF")
        }
        defer { try? FileManager.default.removeItem(at: testPDF) }

        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()

        pdfController.load(url: testPDF)
        await waitForLoad(pdfController)

        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory

        XCTAssertLessThan(loadTime, 10.0, "Large PDF should load within 10 seconds")
        XCTAssertLessThan(memoryIncrease, 500 * 1024 * 1024, "Memory increase should be less than 500MB")
        XCTAssertNotNil(pdfController.document)
        XCTAssertTrue(pdfController.isLargePDF)
        XCTAssertGreaterThanOrEqual(pdfController.document?.pageCount ?? 0, 500)
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsageWithLargePDF() async throws {
        guard let testPDF = createTestLargePDF(pageCount: 600) else {
            throw XCTSkip("Could not create test PDF")
        }
        defer { try? FileManager.default.removeItem(at: testPDF) }

        let initialMemory = getCurrentMemoryUsage()

        pdfController.load(url: testPDF)
        await waitForLoad(pdfController)

        let loadedMemory = getCurrentMemoryUsage()
        let memoryIncrease = loadedMemory - initialMemory

        // Navigate through several pages
        let navigationStartMemory = getCurrentMemoryUsage()
        for i in stride(from: 0, to: min(100, pdfController.document?.pageCount ?? 0), by: 10) {
            pdfController.goToPage(i)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        let navigationEndMemory = getCurrentMemoryUsage()
        let navigationMemoryIncrease = navigationEndMemory - navigationStartMemory

        XCTAssertLessThan(memoryIncrease, 400 * 1024 * 1024, "Initial load memory increase should be reasonable")
        XCTAssertLessThan(navigationMemoryIncrease, 50 * 1024 * 1024, "Navigation should not significantly increase memory")
    }

    // MARK: - Search Performance Tests

    func testSearchPerformanceOnLargePDF() async throws {
        // Use fewer pages to keep search time reasonable under parallel test load
        guard let testPDF = createTestLargePDF(pageCount: 200) else {
            throw XCTSkip("Could not create test PDF")
        }
        defer { try? FileManager.default.removeItem(at: testPDF) }

        pdfController.load(url: testPDF)
        await waitForLoad(pdfController)

        guard pdfController.document != nil else {
            throw XCTSkip("PDF not loaded")
        }

        // Use fewer search terms to reduce total test time
        let searchTerms = ["test", "page"]

        for term in searchTerms {
            let startTime = CFAbsoluteTimeGetCurrent()

            if pdfController.isLargePDF {
                pdfController.performSearchOptimized(term)
            } else {
                pdfController.performSearch(term)
            }

            // Wait for search to complete
            var searchAttempts = 0
            while pdfController.isSearching && searchAttempts < 100 {
                try await Task.sleep(nanoseconds: 100_000_000)
                searchAttempts += 1
            }

            let searchTime = CFAbsoluteTimeGetCurrent() - startTime

            XCTAssertLessThan(searchTime, 10.0, "Search for '\(term)' should complete within 10 seconds")
            XCTAssertFalse(pdfController.isSearching, "Search should complete")
        }
    }

    // MARK: - Navigation Performance Tests

    func testNavigationPerformanceOnLargePDF() async throws {
        guard let testPDF = createTestLargePDF(pageCount: 600) else {
            throw XCTSkip("Could not create test PDF")
        }
        defer { try? FileManager.default.removeItem(at: testPDF) }

        pdfController.load(url: testPDF)
        await waitForLoad(pdfController)

        guard let document = pdfController.document else {
            throw XCTSkip("PDF not loaded")
        }

        let pageCount = document.pageCount
        let testPages = [0, pageCount / 4, pageCount / 2, 3 * pageCount / 4, pageCount - 1]

        for pageIndex in testPages {
            let startTime = CFAbsoluteTimeGetCurrent()

            pdfController.goToPage(pageIndex)
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms

            let navigationTime = CFAbsoluteTimeGetCurrent() - startTime

            XCTAssertLessThan(navigationTime, 1.0, "Navigation to page \(pageIndex) should be fast")
            XCTAssertEqual(pdfController.currentPageIndex, pageIndex, "Should navigate to correct page")
        }
    }

    // MARK: - Outline Building Performance Tests

    func testOutlineBuildingPerformance() async throws {
        guard let testPDF = createTestLargePDF(pageCount: 500) else {
            throw XCTSkip("Could not create test PDF")
        }
        defer { try? FileManager.default.removeItem(at: testPDF) }

        pdfController.load(url: testPDF)
        await waitForLoad(pdfController)

        guard pdfController.document != nil else {
            throw XCTSkip("PDF not loaded")
        }

        // Test outline building performance
        let startTime = CFAbsoluteTimeGetCurrent()
        pdfController.rebuildOutlineMap()
        let outlineTime = CFAbsoluteTimeGetCurrent() - startTime

        // Outline building should complete quickly regardless of content
        XCTAssertLessThan(outlineTime, 3.0, "Outline building should complete within 3 seconds")
        // Programmatically-created PDFs have no outline data, so outlineMap will be empty.
        // The performance test verifies the operation completes without hanging or crashing.
    }

    // MARK: - Stress Tests

    func testLargePDFStressTest() async throws {
        guard let testPDF = createTestLargePDF(pageCount: 400) else {
            throw XCTSkip("Could not create test PDF")
        }
        defer { try? FileManager.default.removeItem(at: testPDF) }

        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()

        for _ in 0..<5 {
            pdfController.load(url: testPDF)
            await waitForLoad(pdfController)

            if let document = pdfController.document {
                let randomPage = Int.random(in: 0..<min(100, document.pageCount))
                pdfController.goToPage(randomPage)

                pdfController.performSearch("test")
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }

            pdfController.clearSession()
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory

        XCTAssertLessThan(totalTime, 30.0, "Stress test should complete within 30 seconds")
        XCTAssertLessThan(memoryIncrease, 200 * 1024 * 1024, "Memory should not leak significantly")
    }

    // MARK: - Helper Methods

    /// Creates a large PDF using PDFKit with the specified page count
    private func createTestLargePDF(pageCount: Int) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_large_\(pageCount)_\(UUID().uuidString).pdf")

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
        // Wait for debounce to trigger (0.1s) + buffer
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Poll for loading to complete
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

    private func getCurrentMemoryUsage() -> UInt64 {
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
        }
        return 0
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
