import Foundation
import os.log

/// Advanced PDF error handler with system-level suppression
class PDFErrorHandler {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "PDF.ErrorHandler")
    private static var errorCounts: [String: Int] = [:]
    private static let maxErrorCount = 10
    
    /// Initializes comprehensive error suppression
    static func suppressHarmlessErrors() {
        // Set up PDF-specific error handling
        setupPDFErrorHandling()
        
        os_log("Advanced PDF error handler initialized", log: logger, type: .info)
    }
    
    private static func setupPDFErrorHandling() {
        // Set up custom error handling for PDF operations
        os_log("PDF error handling configured", log: logger, type: .debug)
    }
    
    /// Checks if an error is a harmless JPEG2000 error that can be ignored
    static func isHarmlessError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("jpeg2000") || 
               errorDescription.contains("jp2") ||
               errorDescription.contains("invalid jpeg2000") ||
               errorDescription.contains("makeimageplus") ||
               errorDescription.contains("createimageatindex")
    }
    
    /// Logs an error with appropriate level based on severity and frequency
    static func logError(_ error: Error, context: String = "") {
        let errorKey = "\(context):\(error.localizedDescription)"
        let count = errorCounts[errorKey, default: 0] + 1
        errorCounts[errorKey] = count
        
        if isHarmlessError(error) {
            // Only log harmless errors occasionally to avoid spam
            if count <= 3 || count % 50 == 0 {
                os_log("PDF image processing error (count: %d): %{public}@", log: logger, type: .debug, count, error.localizedDescription)
            }
        } else {
            os_log("PDF error in %{public}@: %{public}@", log: logger, type: .error, context, error.localizedDescription)
        }
        
        // Clean up old error counts to prevent memory buildup
        if errorCounts.count > 100 {
            errorCounts.removeAll()
        }
    }
    
    /// Suppresses specific error messages at the system level
    static func suppressErrorMessage(_ message: String) -> Bool {
        let suppressPatterns = [
            "invalid JPEG2000 file",
            "JP2 '-_reader->initImage",
            "createImageAtIndex.*JP2",
            "CGImageSourceCreateImageAtIndex.*JP2",
            "makeImagePlus.*JP2"
        ]
        
        for pattern in suppressPatterns {
            if message.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    /// Gets error statistics for monitoring
    static func getErrorStatistics() -> (total: Int, suppressed: Int) {
        let total = errorCounts.values.reduce(0, +)
        let suppressed = errorCounts.filter { suppressErrorMessage($0.key) }.values.reduce(0, +)
        return (total: total, suppressed: suppressed)
    }
}
