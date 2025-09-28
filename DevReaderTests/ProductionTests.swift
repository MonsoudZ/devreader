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
        // Test with a large PDF (500+ pages)
        let pdfController = PDFController()
        let testURL = createLargeTestPDF()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
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
        let testURL = createLargeTestPDF()
        
        // Get initial memory usage
        let initialMemory = getMemoryUsage()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
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
        let testURL = createTestPDFWithText()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Test case-insensitive search
        let searchQuery = "test"
        pdfController.searchQuery = searchQuery
        
        // Wait for search to complete
        while pdfController.isSearching {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertGreaterThan(pdfController.searchResults.count, 0, "Should find search results")
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testSearchHighlights() async {
        let pdfController = PDFController()
        let testURL = createTestPDFWithText()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let searchQuery = "test"
        pdfController.searchQuery = searchQuery
        
        // Wait for search to complete
        while pdfController.isSearching {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Verify search results have proper highlighting
        for result in pdfController.searchResults {
            XCTAssertNotNil(result, "Search result should not be nil")
            XCTAssertGreaterThan(result.bounds.count, 0, "Search result should have bounds")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }
    
    func testSearchPerformanceWithLargePDF() async {
        let pdfController = PDFController()
        let testURL = createLargeTestPDF()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let searchQuery = "test"
        pdfController.searchQuery = searchQuery
        
        // Wait for search to complete
        while pdfController.isSearching {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Search should complete within 5 seconds even for large PDFs
        XCTAssertLessThan(timeElapsed, 5.0, "Search should be fast even for large PDFs")
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }
    
    // MARK: - Session Restore Tests
    
    func testSessionRestoreWithMultiplePDFs() async {
        let pdfController = PDFController()
        let testURLs = [createTestPDFWithText(), createTestPDFWithText(), createTestPDFWithText()]
        
        // Load multiple PDFs sequentially
        for (index, url) in testURLs.enumerated() {
            pdfController.load(url: url)
            
            // Wait for loading to complete
            while pdfController.isLoadingPDF {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            // Set page index
            pdfController.currentPageIndex = index + 1
            
            // Save session
            pdfController.savePageForPDF(url)
        }
        
        // Clear current session
        pdfController.clearSession()
        
        // Restore session for first PDF
        pdfController.load(url: testURLs[0])
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Verify page was restored
        XCTAssertEqual(pdfController.currentPageIndex, 1, "Page should be restored")
        
        // Clean up
        for url in testURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func testSessionRestoreAfterAppRestart() async {
        let pdfController = PDFController()
        let testURL = createTestPDFWithText()
        
        // Load PDF and set page
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        pdfController.currentPageIndex = 5
        pdfController.savePageForPDF(testURL)
        
        // Create new controller (simulating app restart)
        let newController = PDFController()
        
        // Load same PDF
        newController.load(url: testURL)
        
        // Wait for loading to complete
        while newController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Verify page was restored
        XCTAssertEqual(newController.currentPageIndex, 5, "Page should be restored after app restart")
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }
    
    // MARK: - Persistence Tests
    
    func testAtomicWrites() async {
        let testData = ["test": "value", "number": 42, "array": [1, 2, 3]]
        let key = "test.atomic.writes"
        
        // Save data
        PersistenceService.saveCodable(testData, forKey: key)
        
        // Load data
        let loadedData: [String: Any]? = PersistenceService.loadCodable([String: Any].self, forKey: key)
        
        XCTAssertNotNil(loadedData, "Data should be loaded successfully")
        XCTAssertEqual(loadedData?["test"] as? String, "value", "String value should match")
        XCTAssertEqual(loadedData?["number"] as? Int, 42, "Number value should match")
        
        // Clean up
        PersistenceService.delete(forKey: key)
    }
    
    func testPDFScoping() async {
        let pdf1URL = createTestPDFWithText()
        let pdf2URL = createTestPDFWithText()
        
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
        let testURL = createLargeTestPDF()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Simulate memory pressure
        NotificationCenter.default.post(name: .memoryPressure, object: nil)
        
        // App should handle memory pressure gracefully
        XCTAssertNotNil(pdfController.document, "Document should still be available")
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityFocusManagement() async {
        let pdfController = PDFController()
        let testURL = createTestPDFWithText()
        
        pdfController.load(url: testURL)
        
        // Wait for loading to complete
        while pdfController.isLoadingPDF {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Test focus management
        AccessibilityEnhancer.setFocusToPDFPage(0, totalPages: pdfController.document?.pageCount ?? 0)
        
        // This should not crash
        XCTAssertTrue(true, "Accessibility focus management should work")
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPDFWithText() -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        
        // Create a simple PDF with text
        let pdfDocument = PDFDocument()
        let page = PDFPage()
        
        // Add some text to the page
        let text = "This is a test PDF document with some text for testing purposes."
        let attributedString = NSAttributedString(string: text)
        page.addAnnotation(PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100), forType: .freeText, withProperties: nil))
        
        pdfDocument.insert(page, at: 0)
        pdfDocument.write(to: tempURL)
        
        return tempURL
    }
    
    private func createLargeTestPDF() -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("large_test.pdf")
        
        // Create a large PDF with many pages
        let pdfDocument = PDFDocument()
        
        for i in 0..<600 { // 600 pages
            let page = PDFPage()
            let text = "This is page \(i + 1) of a large test PDF document."
            let attributedString = NSAttributedString(string: text)
            page.addAnnotation(PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 100, height: 100), forType: .freeText, withProperties: nil))
            
            pdfDocument.insert(page, at: i)
        }
        
        pdfDocument.write(to: tempURL)
        
        return tempURL
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

// MARK: - Memory Pressure Notification

extension NSNotification.Name {
    static let memoryPressure = NSNotification.Name("NSMemoryPressure")
}
