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
