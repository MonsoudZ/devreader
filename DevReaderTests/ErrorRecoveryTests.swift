import XCTest
import PDFKit
@testable import DevReader

final class ErrorRecoveryTests: XCTestCase {
    
    override func tearDownWithError() throws {
        // Clean up any temporary files created during tests
        let tempDir = FileManager.default.temporaryDirectory
        let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        tempFiles?.forEach { file in
            if file.lastPathComponent.hasPrefix("test_") && file.pathExtension == "pdf" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - PDF Validation Tests
    
    func testValidatePDFIntegrity() {
        // Create a simple PDF for testing
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_validation.pdf")
        
        do {
            // Save PDF
            let data = pdf.dataRepresentation()
            try data?.write(to: tempFile)
            
            // Test validation
            let isValid = ErrorRecoveryService.validatePDFIntegrity(at: tempFile)
            XCTAssertTrue(isValid, "Valid PDF should pass integrity check")
            
            // Clean up
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("PDF validation test failed: \(error)")
        }
    }
    
    func testValidateCorruptedPDF() {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_corrupted.pdf")
        
        do {
            // Create a corrupted PDF file
            let corruptedData = "This is not a valid PDF file content"
            try corruptedData.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Test validation
            let isValid = ErrorRecoveryService.validatePDFIntegrity(at: tempFile)
            XCTAssertFalse(isValid, "Corrupted PDF should fail integrity check")
            
            // Clean up
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("Corrupted PDF validation test failed: \(error)")
        }
    }
    
    func testValidateNonExistentPDF() {
        let tempDir = FileManager.default.temporaryDirectory
        let nonExistentFile = tempDir.appendingPathComponent("non_existent.pdf")
        
        // Test validation of non-existent file
        let isValid = ErrorRecoveryService.validatePDFIntegrity(at: nonExistentFile)
        XCTAssertFalse(isValid, "Non-existent PDF should fail integrity check")
    }
    
    // MARK: - PDF Repair Tests
    
    func testSanitizeAndRewritePDF() {
        // Create a simple PDF for testing
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        
        let tempDir = FileManager.default.temporaryDirectory
        let originalFile = tempDir.appendingPathComponent("test_original.pdf")
        let repairedFile = tempDir.appendingPathComponent("test_repaired.pdf")
        
        do {
            // Save original PDF
            let data = pdf.dataRepresentation()
            try data?.write(to: originalFile)
            
            // Test repair
            let repairResult = ErrorRecoveryService.sanitizeAndRewritePDF(from: originalFile, to: repairedFile)
            XCTAssertTrue(repairResult, "PDF repair should succeed")
            
            // Verify repaired file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: repairedFile.path), "Repaired file should exist")
            
            // Verify repaired file is valid
            let isValid = ErrorRecoveryService.validatePDFIntegrity(at: repairedFile)
            XCTAssertTrue(isValid, "Repaired PDF should be valid")
            
            // Clean up
            try FileManager.default.removeItem(at: originalFile)
            try FileManager.default.removeItem(at: repairedFile)
        } catch {
            XCTFail("PDF repair test failed: \(error)")
        }
    }
    
    func testRebuildPDFByDrawing() {
        // Create a simple PDF for testing
        let pdf = PDFDocument()
        let page = PDFPage()
        pdf.insert(page, at: 0)
        
        let tempDir = FileManager.default.temporaryDirectory
        let originalFile = tempDir.appendingPathComponent("test_original_draw.pdf")
        let rebuiltFile = tempDir.appendingPathComponent("test_rebuilt.pdf")
        
        do {
            // Save original PDF
            let data = pdf.dataRepresentation()
            try data?.write(to: originalFile)
            
            // Test rebuild
            let rebuildResult = ErrorRecoveryService.rebuildPDFByDrawing(from: originalFile, to: rebuiltFile)
            XCTAssertTrue(rebuildResult, "PDF rebuild should succeed")
            
            // Verify rebuilt file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: rebuiltFile.path), "Rebuilt file should exist")
            
            // Verify rebuilt file is valid
            let isValid = ErrorRecoveryService.validatePDFIntegrity(at: rebuiltFile)
            XCTAssertTrue(isValid, "Rebuilt PDF should be valid")
            
            // Clean up
            try FileManager.default.removeItem(at: originalFile)
            try FileManager.default.removeItem(at: rebuiltFile)
        } catch {
            XCTFail("PDF rebuild test failed: \(error)")
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testRetryOperation() {
        var attemptCount = 0
        let maxRetries = 3
        
        let result = ErrorRecoveryService.retryOperation(maxRetries: maxRetries) {
            attemptCount += 1
            if attemptCount < 3 {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated error"])
            }
            return true
        }
        
        XCTAssertTrue(result, "Retry operation should eventually succeed")
        XCTAssertEqual(attemptCount, 3, "Should have retried 3 times")
    }
    
    func testRetryOperationFailure() {
        var attemptCount = 0
        let maxRetries = 2
        
        let result = ErrorRecoveryService.retryOperation(maxRetries: maxRetries) {
            attemptCount += 1
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Persistent error"])
        }
        
        XCTAssertFalse(result, "Retry operation should fail after max retries")
        XCTAssertEqual(attemptCount, 3, "Should have attempted 3 times (initial + 2 retries)")
    }
    
    func testRecoverFileAccess() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_recovery.pdf")
        
        do {
            // Create a test file
            try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
            
            // Test file access recovery
            let recoveryResult = ErrorRecoveryService.recoverFileAccess(at: testFile)
            XCTAssertTrue(recoveryResult, "File access recovery should succeed")
            
            // Verify file is accessible
            let content = try String(contentsOf: testFile, encoding: .utf8)
            XCTAssertEqual(content, "Test content", "File should be accessible after recovery")
            
            // Clean up
            try FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("File access recovery test failed: \(error)")
        }
    }
    
    func testDetectDataCorruption() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_corruption.pdf")
        
        do {
            // Create a file with potential corruption (null bytes)
            let corruptedData = Data([0x00, 0x01, 0x02, 0x00, 0x03, 0x00, 0x04])
            try corruptedData.write(to: testFile)
            
            // Test corruption detection
            let isCorrupted = ErrorRecoveryService.detectDataCorruption(at: testFile)
            XCTAssertTrue(isCorrupted, "Should detect data corruption")
            
            // Clean up
            try FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("Data corruption detection test failed: \(error)")
        }
    }
    
    func testDetectNoCorruption() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_no_corruption.pdf")
        
        do {
            // Create a normal file
            try "Normal file content".write(to: testFile, atomically: true, encoding: .utf8)
            
            // Test corruption detection
            let isCorrupted = ErrorRecoveryService.detectDataCorruption(at: testFile)
            XCTAssertFalse(isCorrupted, "Should not detect corruption in normal file")
            
            // Clean up
            try FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("No corruption detection test failed: \(error)")
        }
    }
    
    // MARK: - Session Recovery Tests
    
    func testRecoverSession() {
        let testURL = URL(fileURLWithPath: "/tmp/test_session.pdf")
        let testPage = 5
        
        // Test session recovery
        let recoveryResult = ErrorRecoveryService.recoverSession(
            pdfURL: testURL,
            lastPage: testPage,
            bookmarks: [1, 3, 5],
            notes: ["Test note 1", "Test note 2"]
        )
        
        XCTAssertTrue(recoveryResult, "Session recovery should succeed")
    }
    
    // MARK: - Performance Tests
    
    func testErrorRecoveryPerformance() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_performance.pdf")
        
        do {
            // Create a test PDF
            let pdf = PDFDocument()
            let page = PDFPage()
            pdf.insert(page, at: 0)
            let data = pdf.dataRepresentation()
            try data?.write(to: testFile)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Test multiple recovery operations
            for _ in 0..<10 {
                let _ = ErrorRecoveryService.validatePDFIntegrity(at: testFile)
                let _ = ErrorRecoveryService.detectDataCorruption(at: testFile)
                let _ = ErrorRecoveryService.recoverFileAccess(at: testFile)
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 5.0, "Error recovery operations should complete within 5 seconds")
            
            // Clean up
            try FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("Error recovery performance test failed: \(error)")
        }
    }
    
    func testPDFRepairPerformance() {
        let tempDir = FileManager.default.temporaryDirectory
        let originalFile = tempDir.appendingPathComponent("test_repair_performance.pdf")
        let repairedFile = tempDir.appendingPathComponent("test_repaired_performance.pdf")
        
        do {
            // Create a test PDF
            let pdf = PDFDocument()
            let page = PDFPage()
            pdf.insert(page, at: 0)
            let data = pdf.dataRepresentation()
            try data?.write(to: originalFile)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Test repair operations
            let _ = ErrorRecoveryService.sanitizeAndRewritePDF(from: originalFile, to: repairedFile)
            let _ = ErrorRecoveryService.rebuildPDFByDrawing(from: originalFile, to: repairedFile)
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 10.0, "PDF repair operations should complete within 10 seconds")
            
            // Clean up
            try FileManager.default.removeItem(at: originalFile)
            try FileManager.default.removeItem(at: repairedFile)
        } catch {
            XCTFail("PDF repair performance test failed: \(error)")
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyPDFValidation() {
        let tempDir = FileManager.default.temporaryDirectory
        let emptyFile = tempDir.appendingPathComponent("test_empty.pdf")
        
        do {
            // Create empty file
            try Data().write(to: emptyFile)
            
            // Test validation
            let isValid = ErrorRecoveryService.validatePDFIntegrity(at: emptyFile)
            XCTAssertFalse(isValid, "Empty PDF should fail validation")
            
            // Clean up
            try FileManager.default.removeItem(at: emptyFile)
        } catch {
            XCTFail("Empty PDF validation test failed: \(error)")
        }
    }
    
    func testLargePDFValidation() {
        let tempDir = FileManager.default.temporaryDirectory
        let largeFile = tempDir.appendingPathComponent("test_large.pdf")
        
        do {
            // Create a PDF with multiple pages
            let pdf = PDFDocument()
            for i in 0..<100 {
                let page = PDFPage()
                pdf.insert(page, at: i)
            }
            
            let data = pdf.dataRepresentation()
            try data?.write(to: largeFile)
            
            // Test validation
            let isValid = ErrorRecoveryService.validatePDFIntegrity(at: largeFile)
            XCTAssertTrue(isValid, "Large PDF should pass validation")
            
            // Clean up
            try FileManager.default.removeItem(at: largeFile)
        } catch {
            XCTFail("Large PDF validation test failed: \(error)")
        }
    }
    
    func testConcurrentErrorRecovery() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFiles = (0..<5).map { tempDir.appendingPathComponent("test_concurrent_\($0).pdf") }
        
        do {
            // Create multiple test files
            for file in testFiles {
                let pdf = PDFDocument()
                let page = PDFPage()
                pdf.insert(page, at: 0)
                let data = pdf.dataRepresentation()
                try data?.write(to: file)
            }
            
            let expectation = XCTestExpectation(description: "Concurrent error recovery")
            expectation.expectedFulfillmentCount = testFiles.count
            
            // Test concurrent validation
            for file in testFiles {
                DispatchQueue.global().async {
                    let _ = ErrorRecoveryService.validatePDFIntegrity(at: file)
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
            
            // Clean up
            for file in testFiles {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            XCTFail("Concurrent error recovery test failed: \(error)")
        }
    }
}
