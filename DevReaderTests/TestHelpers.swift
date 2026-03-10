import Foundation
import PDFKit
@testable import DevReader

// MARK: - PDF Creation Helpers

/// Creates a multi-page test PDF using PDFKit.
/// - Parameters:
///   - pageCount: Number of blank pages to create.
///   - name: Optional filename prefix. A UUID suffix is always appended.
/// - Returns: URL to the created PDF in the temporary directory.
func createTestPDF(pageCount: Int, name: String = "test") -> URL {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(name)_\(UUID().uuidString).pdf")

    let pdfDocument = PDFDocument()
    for i in 0..<pageCount {
        let page = PDFPage()
        pdfDocument.insert(page, at: i)
    }
    pdfDocument.write(to: tempURL)

    return tempURL
}

// MARK: - Async Load Helper

/// Waits for a PDFController's async load to complete.
/// Accounts for the 0.1s internal debounce, then polls `isLoadingPDF`.
@MainActor
func waitForLoad(_ controller: PDFController) async {
    // Wait for debounce to trigger (0.1s) + buffer
    try? await Task.sleep(nanoseconds: 200_000_000)

    // Poll for loading to complete
    var attempts = 0
    while controller.isLoadingPDF && attempts < 100 {
        try? await Task.sleep(nanoseconds: 100_000_000)
        attempts += 1
    }

    // Extra settle time for document assignment
    if controller.document == nil {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
}

// MARK: - Lightweight Temp PDF Helpers

/// Creates a minimal PDF stub file (not a real PDFKit document).
/// Suitable for tests that only need a file to exist (e.g., library, persistence).
/// Uses a UUID suffix to prevent collisions between parallel test runs.
func makeTempPDFStub(named prefix: String = "test") -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)_\(UUID().uuidString).pdf")
    try? "%PDF-1.4\n%%EOF".data(using: .utf8)?.write(to: url)
    return url
}

/// Creates a temp file with arbitrary content, useful for key-generation tests.
/// Uses a UUID suffix to prevent collisions between parallel test runs.
func makeTempFile(named prefix: String = "test", extension ext: String = "pdf", content: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)_\(UUID().uuidString).\(ext)")
    try? content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

// MARK: - Polling Helpers

/// Polls a condition at short intervals, returning when it becomes true or timeout is reached.
@MainActor
func waitUntil(timeout: TimeInterval = 2.0, interval: UInt64 = 50_000_000, condition: @MainActor () -> Bool) async {
    let deadline = CFAbsoluteTimeGetCurrent() + timeout
    while !condition() && CFAbsoluteTimeGetCurrent() < deadline {
        try? await Task.sleep(nanoseconds: interval)
    }
}

// MARK: - PDFDocument Factory

/// Creates a blank PDFDocument with the given number of pages.
/// Shared helper to avoid duplicating makeDoc() across test files.
func makeDoc(pageCount: Int) -> PDFDocument {
    let doc = PDFDocument()
    for i in 0..<pageCount {
        doc.insert(PDFPage(), at: i)
    }
    return doc
}

// MARK: - Memory Measurement

/// Returns the current resident memory size of this process in bytes.
func getMemoryUsage() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }

    return kerr == KERN_SUCCESS ? info.resident_size : 0
}

/// Returns a signed memory delta (handles underflow from GC/deallocation).
func signedMemoryDelta(after: UInt64, before: UInt64) -> Int64 {
    if after >= before {
        return Int64(after - before)
    }
    return -Int64(before - after)
}
