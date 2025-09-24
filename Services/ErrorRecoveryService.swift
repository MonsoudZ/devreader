import Foundation
import os.log
import CoreGraphics
import PDFKit
import AppKit

// Service for handling automatic retry mechanisms and error recovery
enum ErrorRecoveryService {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "ErrorRecovery")
    
    // MARK: - Retry Configuration
    struct RetryConfig {
        let maxAttempts: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double
        
        nonisolated static let `default` = RetryConfig(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 2.0,
            backoffMultiplier: 2.0
        )
    }
    
    // MARK: - Retry with Exponential Backoff
    static func retry<T>(
        operation: @escaping () throws -> T,
        config: RetryConfig = .default,
        onFailure: ((Error) -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        var delay = config.baseDelay
        
        for attempt in 1...config.maxAttempts {
            do {
                let result = try operation()
                if attempt > 1 {
                    os_log("Retry succeeded on attempt %d", log: logger, type: .info, attempt)
                }
                return result
            } catch {
                lastError = error
                onFailure?(error)
                
                if attempt < config.maxAttempts {
                    os_log("Retry attempt %d/%d failed: %{public}@, retrying in %.2fs", 
                           log: logger, type: .info, attempt, config.maxAttempts, error.localizedDescription, delay)
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay = min(delay * config.backoffMultiplier, config.maxDelay)
                } else {
                    os_log("All retry attempts failed", log: logger, type: .error)
                }
            }
        }
        
        throw lastError ?? NSError(domain: "ErrorRecoveryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }
    
    // MARK: - File System Recovery
    static func recoverFileAccess(for url: URL) async -> Bool {
        do {
            // Check if file exists and is accessible
            guard FileManager.default.fileExists(atPath: url.path) else {
                os_log("File does not exist: %{public}@", log: logger, type: .error, url.path)
                return false
            }
            
            // Try to read file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int, fileSize > 0 else {
                os_log("File is empty or inaccessible: %{public}@", log: logger, type: .error, url.path)
                return false
            }
            
            // Try to open file for reading
            let handle = try FileHandle(forReadingFrom: url)
            defer { handle.closeFile() }
            
            // Read a small amount to test access
            _ = try handle.read(upToCount: 1024)
            
            os_log("File access recovered: %{public}@", log: logger, type: .info, url.path)
            return true
        } catch {
            os_log("File access recovery failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Data Corruption Detection
    static func detectDataCorruption(in data: Data) -> [CorruptionType] {
        var corruptions: [CorruptionType] = []
        
        // Check for empty data
        if data.isEmpty {
            corruptions.append(.empty)
        }
        
        // Check for PDF header
        if data.count >= 4 {
            let header = String(data: data.prefix(4), encoding: .ascii)
            if header != "%PDF" {
                corruptions.append(.invalidHeader)
            }
        }
        
        // Check for null bytes (common in corrupted files)
        if data.contains(0) {
            corruptions.append(.nullBytes)
        }
        
        // Check for reasonable file size
        if data.count < 100 {
            corruptions.append(.tooSmall)
        }
        
        return corruptions
    }
    
    // MARK: - PDF Data Sanitation
    /// Attempts light-weight sanitation of PDF bytes. Returns cleaned data if successful.
    static func sanitizePDFData(_ data: Data) -> Data? {
        var bytes = data
        // Ensure header
        if !(bytes.prefix(4) == Data("%PDF".utf8)) {
            os_log("Sanitize: Missing %PDF header", log: logger, type: .error)
            return nil
        }
        // Trim leading/trailing null bytes which sometimes break parsers
        let trimmed = bytes.drop(while: { $0 == 0x00 }).reversed().drop(while: { $0 == 0x00 }).reversed()
        bytes = Data(trimmed)
        // Ensure EOF marker exists; if not, append
        if let eofRange = bytes.range(of: Data("%%EOF".utf8)) {
            // keep as is
            _ = eofRange
        } else {
            os_log("Sanitize: Appending missing %%EOF marker", log: logger, type: .info)
            bytes.append(contentsOf: Array("\n%%EOF\n".utf8))
        }
        return bytes
    }
    
    // MARK: - Repair Strategies
    /// Strategy A: Re-encode using PDFKit (load from data, write back)
    static func rebuildPDFByRewriting(_ data: Data, to url: URL) -> Bool {
        if let doc = PDFDocument(data: data) {
            if let outData = doc.dataRepresentation() {
                do { try outData.write(to: url); return true } catch {
                    os_log("Rewriting failed: %{public}@", log: logger, type: .error, error.localizedDescription)
                }
            }
        }
        return false
    }
    
    /// Strategy B: Draw each page into a fresh PDF context to normalize content streams
    static func rebuildPDFByDrawing(from source: PDFDocument, to url: URL) -> Bool {
        guard let consumer = CGDataConsumer(url: url as CFURL) else { return false }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return false }
        defer { context.closePDF() }
        let pageCount = source.pageCount
        for index in 0..<pageCount {
            guard let page = source.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            var box = bounds
            context.beginPDFPage([kCGPDFContextMediaBox as String: box] as CFDictionary)
            // Flip context to match PDFKit coordinate system
            context.saveGState()
            context.translateBy(x: 0, y: box.height)
            context.scaleBy(x: 1, y: -1)
            if let cgPage = page.pageRef {
                context.drawPDFPage(cgPage)
            } else {
                // Fallback: render to image and draw
                let img = page.thumbnail(of: bounds.size, for: .mediaBox)
                if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    context.draw(cg, in: box)
                }
            }
            context.restoreGState()
            context.endPDFPage()
        }
        return true
    }
    
    /// Validates that a PDF at URL can be opened by CoreGraphics (stricter than PDFKit sometimes)
    static func cgpdfOpens(_ url: URL) -> Bool {
        guard let provider = CGDataProvider(url: url as CFURL), let cg = CGPDFDocument(provider) else { return false }
        return cg.numberOfPages > 0
    }
    
    // MARK: - Session Recovery
    static func recoverSession() async -> Bool {
        os_log("Starting session recovery", log: logger, type: .info)
        
        do {
            // Clear potentially corrupted UserDefaults
            let keys = ["DevReader.Session.v1", "DevReader.Bookmarks.v1", "DevReader.Recents.v1", "DevReader.Pinned.v1"]
            for key in keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            // Clear temporary files
            let tempDir = FileManager.default.temporaryDirectory
            let repairDir = tempDir.appendingPathComponent("DevReaderRepair")
            if FileManager.default.fileExists(atPath: repairDir.path) {
                try FileManager.default.removeItem(at: repairDir)
            }
            
            os_log("Session recovery completed successfully", log: logger, type: .info)
            return true
        } catch {
            os_log("Session recovery failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            return false
        }
    }
}

// MARK: - Corruption Types
enum CorruptionType: String, CaseIterable {
    case empty = "Empty file"
    case invalidHeader = "Invalid PDF header"
    case nullBytes = "Contains null bytes"
    case tooSmall = "File too small"
    case corrupted = "General corruption"
    
    var description: String {
        return self.rawValue
    }
}
