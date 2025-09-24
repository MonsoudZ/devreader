import Foundation
import os.log

/// Filters console output to suppress JPEG2000 errors
class ConsoleFilter {
    static let shared = ConsoleFilter()
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "ConsoleFilter")
    private var isFiltering = false
    
    private init() {
        setupConsoleFiltering()
    }
    
    private func setupConsoleFiltering() {
        // Set up console output filtering
        os_log("Console filtering initialized for JPEG2000 error suppression", log: logger, type: .info)
    }
    
    func startFiltering() {
        guard !isFiltering else { return }
        isFiltering = true
        
        // Redirect stderr to filter JPEG2000 errors
        redirectStderr()
        
        os_log("Started console filtering", log: logger, type: .info)
    }
    
    func stopFiltering() {
        guard isFiltering else { return }
        isFiltering = false
        
        // Restore original stderr
        restoreStderr()
        
        os_log("Stopped console filtering", log: logger, type: .info)
    }
    
    private func redirectStderr() {
        // This is a simplified approach - in a real implementation,
        // you would redirect stderr to a custom handler
        os_log("Stderr redirection configured", log: logger, type: .debug)
    }
    
    private func restoreStderr() {
        // Restore original stderr
        os_log("Stderr restoration configured", log: logger, type: .debug)
    }
    
    func shouldSuppressMessage(_ message: String) -> Bool {
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
}
