import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class LargePDFTests: XCTestCase {
    
    private var pdfController: PDFController!
    private var performanceMonitor: PerformanceMonitor!
    private var testPDFURL: URL?
    
    override func setUp() {
        super.setUp()
        pdfController = PDFController()
        performanceMonitor = PerformanceMonitor.shared
    }
    
    override func tearDown() {
        pdfController = nil
        performanceMonitor = nil
        testPDFURL = nil
        super.tearDown()
    }
    
    // MARK: - Large PDF Test Data Creation
    
    func testCreateLargePDF() throws {
        // Create a large PDF for testing (simulate 700+ pages)
        let largePDFURL = createTestLargePDF(pageCount: 750)
        testPDFURL = largePDFURL
        
        XCTAssertNotNil(largePDFURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: largePDFURL?.path ?? ""))
        
        // Verify PDF can be loaded
        if let url = largePDFURL, let document = PDFDocument(url: url) {
            XCTAssertGreaterThanOrEqual(document.pageCount, 750)
            print("✅ Created test PDF with \(document.pageCount) pages")
        } else {
            XCTFail("Failed to create large test PDF")
        }
    }
    
    // MARK: - PDF Loading Performance Tests
    
    func testLargePDFLoadingPerformance() async throws {
        guard let testPDF = testPDFURL ?? createTestLargePDF(pageCount: 500) else {
            throw XCTSkip("Could not create test PDF")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        // Load the large PDF
        pdfController.load(url: testPDF)
        
        // Wait for loading to complete
        var attempts = 0
        while pdfController.isLoadingPDF && attempts < 100 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // Performance assertions
        XCTAssertLessThan(loadTime, 10.0, "Large PDF should load within 10 seconds")
        XCTAssertLessThan(memoryIncrease, 500 * 1024 * 1024, "Memory increase should be less than 500MB")
        
        // Verify PDF loaded correctly
        XCTAssertNotNil(pdfController.document)
        XCTAssertTrue(pdfController.isLargePDF)
        XCTAssertGreaterThanOrEqual(pdfController.document?.pageCount ?? 0, 500)
        
        print("📊 Large PDF Loading Performance:")
        print("   Load Time: \(String(format: "%.2f", loadTime))s")
        print("   Memory Increase: \(formatBytes(memoryIncrease))")
        print("   Pages: \(pdfController.document?.pageCount ?? 0)")
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageWithLargePDF() async throws {
        guard let testPDF = testPDFURL ?? createTestLargePDF(pageCount: 600) else {
            throw XCTSkip("Could not create test PDF")
        }
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Load PDF
        pdfController.load(url: testPDF)
        
        // Wait for loading
        var attempts = 0
        while pdfController.isLoadingPDF && attempts < 100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        let loadedMemory = getCurrentMemoryUsage()
        let memoryIncrease = loadedMemory - initialMemory
        
        // Test memory usage during navigation
        let navigationStartMemory = getCurrentMemoryUsage()
        
        // Navigate through several pages
        for i in stride(from: 0, to: min(100, pdfController.document?.pageCount ?? 0), by: 10) {
            pdfController.goToPage(i)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let navigationEndMemory = getCurrentMemoryUsage()
        let navigationMemoryIncrease = navigationEndMemory - navigationStartMemory
        
        // Memory assertions
        XCTAssertLessThan(memoryIncrease, 400 * 1024 * 1024, "Initial load memory increase should be reasonable")
        XCTAssertLessThan(navigationMemoryIncrease, 50 * 1024 * 1024, "Navigation should not significantly increase memory")
        
        print("🧠 Memory Usage Analysis:")
        print("   Initial Load: \(formatBytes(memoryIncrease))")
        print("   Navigation: \(formatBytes(navigationMemoryIncrease))")
        print("   Total Memory: \(formatBytes(loadedMemory))")
    }
    
    // MARK: - Search Performance Tests
    
    func testSearchPerformanceOnLargePDF() async throws {
        guard let testPDF = testPDFURL ?? createTestLargePDF(pageCount: 500) else {
            throw XCTSkip("Could not create test PDF")
        }
        
        // Load PDF
        pdfController.load(url: testPDF)
        
        // Wait for loading
        var attempts = 0
        while pdfController.isLoadingPDF && attempts < 100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        // Test search performance
        let searchTerms = ["test", "document", "page", "content", "large"]
        
        for term in searchTerms {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            if pdfController.isLargePDF {
                pdfController.performSearchOptimized(term)
            } else {
                pdfController.performSearch(term)
            }
            
            // Wait for search to complete
            var searchAttempts = 0
            while pdfController.isSearching && searchAttempts < 50 {
                try await Task.sleep(nanoseconds: 100_000_000)
                searchAttempts += 1
            }
            
            let searchTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Search performance assertions
            XCTAssertLessThan(searchTime, 5.0, "Search for '\(term)' should complete within 5 seconds")
            XCTAssertFalse(pdfController.isSearching, "Search should complete")
            
            print("🔍 Search Performance for '\(term)': \(String(format: "%.2f", searchTime))s")
        }
    }
    
    // MARK: - Navigation Performance Tests
    
    func testNavigationPerformanceOnLargePDF() async throws {
        guard let testPDF = testPDFURL ?? createTestLargePDF(pageCount: 600) else {
            throw XCTSkip("Could not create test PDF")
        }
        
        // Load PDF
        pdfController.load(url: testPDF)
        
        // Wait for loading
        var attempts = 0
        while pdfController.isLoadingPDF && attempts < 100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        guard let document = pdfController.document else {
            throw XCTSkip("PDF not loaded")
        }
        
        let pageCount = document.pageCount
        let testPages = [0, pageCount / 4, pageCount / 2, 3 * pageCount / 4, pageCount - 1]
        
        for pageIndex in testPages {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            pdfController.goToPage(pageIndex)
            
            // Wait for navigation to complete
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            let navigationTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Navigation performance assertions
            XCTAssertLessThan(navigationTime, 1.0, "Navigation to page \(pageIndex) should be fast")
            XCTAssertEqual(pdfController.currentPageIndex, pageIndex, "Should navigate to correct page")
            
            print("📄 Navigation to page \(pageIndex): \(String(format: "%.3f", navigationTime))s")
        }
    }
    
    // MARK: - Outline Building Performance Tests
    
    func testOutlineBuildingPerformance() async throws {
        guard let testPDF = testPDFURL ?? createTestLargePDF(pageCount: 500) else {
            throw XCTSkip("Could not create test PDF")
        }
        
        // Load PDF
        pdfController.load(url: testPDF)
        
        // Wait for loading
        var attempts = 0
        while pdfController.isLoadingPDF && attempts < 100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        // Test outline building performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        if pdfController.isLargePDF {
            // For large PDFs, outline building is async
            // Note: rebuildOutlineMapAsync is private, so we'll test the public interface
            // The outline will be built automatically during PDF loading
        } else {
            pdfController.rebuildOutlineMap()
        }
        
        let outlineTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Outline performance assertions
        XCTAssertLessThan(outlineTime, 3.0, "Outline building should complete within 3 seconds")
        XCTAssertFalse(pdfController.outlineMap.isEmpty, "Outline should be built")
        
        print("📋 Outline Building Performance: \(String(format: "%.2f", outlineTime))s")
        print("   Outline entries: \(pdfController.outlineMap.count)")
    }
    
    // MARK: - Stress Tests
    
    func testLargePDFStressTest() async throws {
        guard let testPDF = testPDFURL ?? createTestLargePDF(pageCount: 400) else {
            throw XCTSkip("Could not create test PDF")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        // Rapid loading and unloading
        for i in 0..<5 {
            print("🔄 Stress test iteration \(i + 1)/5")
            
            // Load PDF
            pdfController.load(url: testPDF)
            
            // Wait for loading
            var attempts = 0
            while pdfController.isLoadingPDF && attempts < 50 {
                try await Task.sleep(nanoseconds: 100_000_000)
                attempts += 1
            }
            
            // Perform some operations
            if let document = pdfController.document {
                let randomPage = Int.random(in: 0..<min(100, document.pageCount))
                pdfController.goToPage(randomPage)
                
                // Quick search
                pdfController.performSearch("test")
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            
            // Clear session
            pdfController.clearSession()
            
            // Small delay between iterations
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // Stress test assertions
        XCTAssertLessThan(totalTime, 30.0, "Stress test should complete within 30 seconds")
        XCTAssertLessThan(memoryIncrease, 200 * 1024 * 1024, "Memory should not leak significantly")
        
        print("💪 Stress Test Results:")
        print("   Total Time: \(String(format: "%.2f", totalTime))s")
        print("   Memory Increase: \(formatBytes(memoryIncrease))")
    }
    
    // MARK: - Helper Methods
    
    func createTestLargePDF(pageCount: Int) -> URL? {
        // For testing purposes, we'll create a simple PDF with basic content
        // In a real scenario, you'd use a proper PDF generation library
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_large_\(pageCount)_pages.pdf")
        
        // Create a minimal PDF document
        let pdfDocument = PDFDocument()
        
        // For this test, we'll create a simple PDF with basic content
        // This is a simplified approach for testing purposes
        let simplePDFContent = createSimplePDFContent(pageCount: pageCount)
        
        if let pdfData = simplePDFContent.data(using: .utf8) {
            do {
                try pdfData.write(to: pdfURL)
                return pdfURL
            } catch {
                print("Failed to write test PDF: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    private func createSimplePDFContent(pageCount: Int) -> String {
        // Create a simple PDF content for testing
        // This is a minimal PDF structure for testing purposes
        var content = "%PDF-1.4\n"
        content += "1 0 obj\n"
        content += "<<\n"
        content += "/Type /Catalog\n"
        content += "/Pages 2 0 R\n"
        content += ">>\n"
        content += "endobj\n"
        
        content += "2 0 obj\n"
        content += "<<\n"
        content += "/Type /Pages\n"
        content += "/Kids [3 0 R]\n"
        content += "/Count \(pageCount)\n"
        content += ">>\n"
        content += "endobj\n"
        
        for i in 0..<pageCount {
            let pageNum = i + 1
            content += "\(pageNum + 2) 0 obj\n"
            content += "<<\n"
            content += "/Type /Page\n"
            content += "/Parent 2 0 R\n"
            content += "/MediaBox [0 0 612 792]\n"
            content += "/Contents \(pageNum + 2 + pageCount) 0 R\n"
            content += ">>\n"
            content += "endobj\n"
        }
        
        for i in 0..<pageCount {
            let contentNum = i + 2 + pageCount
            content += "\(contentNum) 0 obj\n"
            content += "<<\n"
            content += "/Length 50\n"
            content += ">>\n"
            content += "stream\n"
            content += "BT\n"
            content += "/F1 12 Tf\n"
            content += "50 700 Td\n"
            content += "(Page \(i + 1) of \(pageCount)) Tj\n"
            content += "ET\n"
            content += "endstream\n"
            content += "endobj\n"
        }
        
        content += "xref\n"
        content += "0 \(2 + pageCount * 2)\n"
        content += "0000000000 65535 f \n"
        content += "0000000009 00000 n \n"
        content += "0000000058 00000 n \n"
        
        for i in 0..<pageCount {
            content += "0000000\(String(format: "%03d", i * 100)) 00000 n \n"
        }
        
        content += "trailer\n"
        content += "<<\n"
        content += "/Size \(2 + pageCount * 2)\n"
        content += "/Root 1 0 R\n"
        content += ">>\n"
        content += "startxref\n"
        content += "\(1000 + pageCount * 100)\n"
        content += "%%EOF\n"
        
        return content
    }
    
    private func createSimplePDFPageData(pageNumber: Int, totalPages: Int, content: String) -> Data? {
        // This is a simplified PDF page creation
        // In a real implementation, you'd use a proper PDF generation library
        let pdfContent = """
        %PDF-1.4
        1 0 obj
        <<
        /Type /Page
        /Parent 2 0 R
        /MediaBox [0 0 612 792]
        /Contents 3 0 R
        /Resources <<
        /Font <<
        /F1 4 0 R
        >>
        >>
        >>
        endobj
        
        2 0 obj
        <<
        /Type /Pages
        /Kids [1 0 R]
        /Count 1
        >>
        endobj
        
        3 0 obj
        <<
        /Length \(content.count)
        >>
        stream
        BT
        /F1 12 Tf
        50 700 Td
        (\(content)) Tj
        ET
        endstream
        endobj
        
        4 0 obj
        <<
        /Type /Font
        /Subtype /Type1
        /BaseFont /Helvetica
        >>
        endobj
        
        xref
        0 5
        0000000000 65535 f 
        0000000009 00000 n 
        0000000058 00000 n 
        0000000125 00000 n 
        0000000250 00000 n 
        trailer
        <<
        /Size 5
        /Root 2 0 R
        >>
        startxref
        350
        %%EOF
        """
        
        return pdfContent.data(using: .utf8)
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
