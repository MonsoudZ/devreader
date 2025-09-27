#!/usr/bin/env swift

import Foundation
import PDFKit

// MARK: - Large PDF Test Runner
// This script can be run to test large PDF performance outside of the main app

class LargePDFTestRunner {
    
    // MARK: - Test Configuration
    
    struct TestConfig {
        let pageCounts: [Int] = [100, 250, 500, 750, 1000]
        let iterations: Int = 3
        let testDirectory: URL
        
        init() {
            let tempDir = FileManager.default.temporaryDirectory
            self.testDirectory = tempDir.appendingPathComponent("DevReaderLargePDFTests")
            
            // Create test directory
            try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Test Results
    
    struct TestResult {
        let pageCount: Int
        let loadTime: TimeInterval
        let memoryUsage: UInt64
        let searchTime: TimeInterval
        let navigationTime: TimeInterval
        let outlineTime: TimeInterval
        let timestamp: Date
        
        var performanceScore: Double {
            let loadScore = max(0, 100 - (loadTime * 10))
            let memoryScore = max(0, 100 - (Double(memoryUsage) / (1024 * 1024 * 1024) * 50))
            let searchScore = max(0, 100 - (searchTime * 20))
            let navScore = max(0, 100 - (navigationTime * 100))
            
            return (loadScore + memoryScore + searchScore + navScore) / 4
        }
    }
    
    private var testResults: [TestResult] = []
    private let config = TestConfig()
    
    // MARK: - Main Test Execution
    
    func runAllTests() {
        print("🚀 Starting Large PDF Performance Tests")
        print("📁 Test Directory: \(config.testDirectory.path)")
        print("📊 Page Counts: \(config.pageCounts)")
        print("🔄 Iterations per test: \(config.iterations)")
        print("")
        
        for pageCount in config.pageCounts {
            print("📄 Testing PDF with \(pageCount) pages...")
            
            for iteration in 1...config.iterations {
                print("  🔄 Iteration \(iteration)/\(config.iterations)")
                
                if let result = runSingleTest(pageCount: pageCount, iteration: iteration) {
                    testResults.append(result)
                    print("    ✅ Score: \(String(format: "%.1f", result.performanceScore))")
                } else {
                    print("    ❌ Test failed")
                }
            }
            
            print("")
        }
        
        generateReport()
    }
    
    // MARK: - Single Test Execution
    
    private func runSingleTest(pageCount: Int, iteration: Int) -> TestResult? {
        // Create test PDF
        guard let pdfURL = createTestPDF(pageCount: pageCount, iteration: iteration) else {
            print("    ❌ Failed to create test PDF")
            return nil
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        // Load PDF
        guard let document = PDFDocument(url: pdfURL) else {
            print("    ❌ Failed to load PDF")
            return nil
        }
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        let loadMemory = getCurrentMemoryUsage()
        let memoryUsage = loadMemory - startMemory
        
        // Test search performance
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        let searchResults = document.findString("test", withOptions: [.caseInsensitive])
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStartTime
        
        // Test navigation performance
        let navStartTime = CFAbsoluteTimeGetCurrent()
        let testPages = [0, pageCount / 4, pageCount / 2, 3 * pageCount / 4, pageCount - 1]
        for pageIndex in testPages {
            if let page = document.page(at: pageIndex) {
                _ = page.thumbnail(of: CGSize(width: 200, height: 200), for: .mediaBox)
            }
        }
        let navigationTime = CFAbsoluteTimeGetCurrent() - navStartTime
        
        // Test outline building
        let outlineStartTime = CFAbsoluteTimeGetCurrent()
        let outline = document.outlineRoot
        let outlineTime = CFAbsoluteTimeGetCurrent() - outlineStartTime
        
        // Cleanup
        try? FileManager.default.removeItem(at: pdfURL)
        
        return TestResult(
            pageCount: pageCount,
            loadTime: loadTime,
            memoryUsage: memoryUsage,
            searchTime: searchTime,
            navigationTime: navigationTime,
            outlineTime: outlineTime,
            timestamp: Date()
        )
    }
    
    // MARK: - Test PDF Creation
    
    private func createTestPDF(pageCount: Int, iteration: Int) -> URL? {
        let pdfURL = config.testDirectory.appendingPathComponent("test_\(pageCount)_pages_\(iteration).pdf")
        
        // Create a simple PDF document
        let pdfDocument = PDFDocument()
        
        for i in 0..<pageCount {
            // Create a simple page with text content
            let pageContent = createPageContent(pageNumber: i + 1, totalPages: pageCount)
            
            // For this test, we'll create a minimal PDF structure
            // In a real scenario, you'd use a proper PDF generation library
            if let pageData = createPDFPageData(content: pageContent, pageNumber: i + 1) {
                if let page = PDFPage(data: pageData) {
                    pdfDocument.insert(page, at: i)
                }
            }
        }
        
        // Save the PDF
        if pdfDocument.write(to: pdfURL) {
            return pdfURL
        }
        
        return nil
    }
    
    private func createPageContent(pageNumber: Int, totalPages: Int) -> String {
        return """
        Page \(pageNumber) of \(totalPages)
        
        This is test content for large PDF performance testing.
        
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
        
        Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
        
        Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.
        
        Test content for performance testing: \(String(repeating: "test ", count: 50))
        """
    }
    
    private func createPDFPageData(content: String, pageNumber: Int) -> Data? {
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
    
    // MARK: - Memory Usage
    
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
    
    // MARK: - Report Generation
    
    private func generateReport() {
        print("📊 Large PDF Performance Test Report")
        print("=" * 50)
        print("")
        
        // Summary statistics
        let totalTests = testResults.count
        let averageScore = testResults.map { $0.performanceScore }.reduce(0, +) / Double(totalTests)
        let bestScore = testResults.map { $0.performanceScore }.max() ?? 0
        let worstScore = testResults.map { $0.performanceScore }.min() ?? 0
        
        print("📈 Performance Summary:")
        print("  Total Tests: \(totalTests)")
        print("  Average Score: \(String(format: "%.1f", averageScore))")
        print("  Best Score: \(String(format: "%.1f", bestScore))")
        print("  Worst Score: \(String(format: "%.1f", worstScore))")
        print("")
        
        // Memory analysis
        let memoryUsages = testResults.map { $0.memoryUsage }
        let avgMemory = memoryUsages.reduce(0, +) / UInt64(memoryUsages.count)
        let peakMemory = memoryUsages.max() ?? 0
        
        print("🧠 Memory Analysis:")
        print("  Average Memory: \(formatBytes(avgMemory))")
        print("  Peak Memory: \(formatBytes(peakMemory))")
        print("")
        
        // Load time analysis
        let loadTimes = testResults.map { $0.loadTime }
        let avgLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        let fastestLoad = loadTimes.min() ?? 0
        let slowestLoad = loadTimes.max() ?? 0
        
        print("⏱️ Load Time Analysis:")
        print("  Average Load Time: \(String(format: "%.2f", avgLoadTime))s")
        print("  Fastest Load: \(String(format: "%.2f", fastestLoad))s")
        print("  Slowest Load: \(String(format: "%.2f", slowestLoad))s")
        print("")
        
        // Performance by page count
        print("📄 Performance by Page Count:")
        for pageCount in config.pageCounts {
            let results = testResults.filter { $0.pageCount == pageCount }
            if !results.isEmpty {
                let avgScore = results.map { $0.performanceScore }.reduce(0, +) / Double(results.count)
                let avgLoadTime = results.map { $0.loadTime }.reduce(0, +) / Double(results.count)
                let avgMemory = results.map { $0.memoryUsage }.reduce(0, +) / UInt64(results.count)
                
                print("  \(pageCount) pages: Score \(String(format: "%.1f", avgScore)), Load \(String(format: "%.2f", avgLoadTime))s, Memory \(formatBytes(avgMemory))")
            }
        }
        print("")
        
        // Recommendations
        print("💡 Recommendations:")
        if avgMemory > 500 * 1024 * 1024 {
            print("  - Consider implementing more aggressive memory management")
        }
        if avgLoadTime > 5.0 {
            print("  - PDF loading is slow, consider progressive loading")
        }
        if averageScore < 70 {
            print("  - Overall performance needs improvement")
        }
        if worstScore < 50 {
            print("  - Some tests show poor performance, investigate bottlenecks")
        }
        
        // Save detailed report
        saveDetailedReport()
    }
    
    private func saveDetailedReport() {
        let reportURL = config.testDirectory.appendingPathComponent("performance_report.md")
        
        var report = "# Large PDF Performance Test Report\n\n"
        report += "Generated: \(Date())\n"
        report += "Total Tests: \(testResults.count)\n\n"
        
        // Detailed results
        report += "## Detailed Results\n\n"
        for result in testResults {
            report += "### \(result.pageCount) pages - \(result.timestamp)\n"
            report += "- Load Time: \(String(format: "%.2f", result.loadTime))s\n"
            report += "- Memory Usage: \(formatBytes(result.memoryUsage))\n"
            report += "- Search Time: \(String(format: "%.2f", result.searchTime))s\n"
            report += "- Navigation Time: \(String(format: "%.2f", result.navigationTime))s\n"
            report += "- Outline Time: \(String(format: "%.2f", result.outlineTime))s\n"
            report += "- Performance Score: \(String(format: "%.1f", result.performanceScore))\n\n"
        }
        
        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            print("📄 Detailed report saved to: \(reportURL.path)")
        } catch {
            print("❌ Failed to save detailed report: \(error)")
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Main Execution

print("🚀 DevReader Large PDF Performance Test Runner")
print("=" * 50)
print("")

let testRunner = LargePDFTestRunner()
testRunner.runAllTests()

print("✅ Large PDF performance testing completed!")
