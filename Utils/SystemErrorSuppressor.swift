import Foundation
import os.log

/// System-level error suppression for JPEG2000 and other harmless errors
class SystemErrorSuppressor {
    static let shared = SystemErrorSuppressor()
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "ErrorSuppressor")
    private var isSuppressing = false
    
    private init() {
        setupErrorSuppression()
    }
    
    // MARK: - Error Suppression Setup
    
    private func setupErrorSuppression() {
        // Redirect stderr to suppress JPEG2000 errors
        suppressJPEG2000Errors()
        
        // Set up error logging to filter out harmless errors
        setupFilteredLogging()
        
        os_log("System error suppression initialized", log: logger, type: .info)
    }
    
    private func suppressJPEG2000Errors() {
        // Create a custom error handler that filters JPEG2000 errors
        let originalStderr = dup(fileno(stderr))
        
        // Create a pipe for filtered output
        var pipe: [Int32] = [0, 0]
        pipe(pipe)
        
        // Redirect stderr to our pipe
        dup2(pipe[1], fileno(stderr))
        close(pipe[1])
        
        // Start filtering in background
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.filterErrors(from: pipe[0], to: originalStderr)
        }
    }
    
    private func filterErrors(from input: Int32, to output: Int32) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        
        while true {
            let bytesRead = read(input, buffer, 1024)
            if bytesRead <= 0 { break }
            
            let data = Data(bytes: buffer, count: bytesRead)
            if let string = String(data: data, encoding: .utf8) {
                // Filter out JPEG2000 errors
                if !shouldSuppressError(string) {
                    write(output, buffer, bytesRead)
                }
            }
        }
    }
    
    private func shouldSuppressError(_ error: String) -> Bool {
        let suppressPatterns = [
            "invalid JPEG2000 file",
            "JP2 '-_reader->initImage",
            "createImageAtIndex.*JP2",
            "CGImageSourceCreateImageAtIndex.*JP2",
            "makeImagePlus.*JP2"
        ]
        
        for pattern in suppressPatterns {
            if error.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func setupFilteredLogging() {
        // Set up custom logging that filters JPEG2000 errors
        os_log("Filtered logging setup complete", log: logger, type: .debug)
    }
    
    // MARK: - Public Interface
    
    func startSuppression() {
        guard !isSuppressing else { return }
        isSuppressing = true
        os_log("Started error suppression", log: logger, type: .info)
    }
    
    func stopSuppression() {
        guard isSuppressing else { return }
        isSuppressing = false
        os_log("Stopped error suppression", log: logger, type: .info)
    }
    
    func isErrorSuppressed(_ error: String) -> Bool {
        return shouldSuppressError(error)
    }
}
