import Foundation
import Combine
import os.log

/// Crash reporting service for DevReader
/// Provides crash detection, logging, and user feedback mechanisms
@MainActor
class CrashReportingService: ObservableObject {
    static let shared = CrashReportingService()
    
    @Published var isEnabled = false
    @Published var crashCount = 0
    @Published var lastCrashDate: Date?
    
    private let logger = Logger(subsystem: "com.devreader.app", category: "CrashReporting")
    private let crashLogPath: URL
    private let maxCrashLogSize: Int = 1024 * 1024 // 1MB
    
    private init() {
        // Set up crash log path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        crashLogPath = documentsPath.appendingPathComponent("DevReader_CrashLog.txt")
        
        // Load previous crash data
        loadCrashData()
        
        // Set up crash detection
        setupCrashDetection()
    }
    
    // MARK: - Public Interface
    
    /// Enable crash reporting (user opt-in)
    func enableCrashReporting() {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "crashReportingEnabled")
        logCrashEvent("Crash reporting enabled by user")
    }
    
    /// Disable crash reporting
    func disableCrashReporting() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "crashReportingEnabled")
        logCrashEvent("Crash reporting disabled by user")
    }
    
    /// Log a crash event
    func logCrash(_ error: Error, context: String = "") {
        guard isEnabled else { return }
        
        let crashInfo = CrashInfo(
            timestamp: Date(),
            error: error,
            context: context,
            appVersion: getAppVersion(),
            systemVersion: getSystemVersion()
        )
        
        logCrashEvent("Crash detected: \(error.localizedDescription)", details: crashInfo)
        incrementCrashCount()
    }
    
    /// Log a non-fatal error
    func logError(_ error: Error, context: String = "") {
        guard isEnabled else { return }
        
        let errorInfo = ErrorInfo(
            timestamp: Date(),
            error: error,
            context: context,
            appVersion: getAppVersion(),
            systemVersion: getSystemVersion()
        )
        
        logCrashEvent("Error logged: \(error.localizedDescription)", details: errorInfo)
    }
    
    /// Export crash logs for support
    func exportCrashLogs() -> URL? {
        guard FileManager.default.fileExists(atPath: crashLogPath.path) else {
            return nil
        }
        
        let exportPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevReader_CrashLog_\(Date().timeIntervalSince1970).txt")
        
        do {
            try FileManager.default.copyItem(at: crashLogPath, to: exportPath)
            return exportPath
        } catch {
            logger.error("Failed to export crash logs: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear crash logs
    func clearCrashLogs() {
        do {
            if FileManager.default.fileExists(atPath: crashLogPath.path) {
                try FileManager.default.removeItem(at: crashLogPath)
            }
            crashCount = 0
            lastCrashDate = nil
            logger.info("Crash logs cleared")
        } catch {
            logger.error("Failed to clear crash logs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCrashDetection() {
        // Check if crash reporting is enabled
        isEnabled = UserDefaults.standard.bool(forKey: "crashReportingEnabled")
        
        // Set up uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                CrashReportingService.shared.handleUncaughtException(exception)
            }
        }
        
        // Note: Signal handlers are complex and can cause issues
        // For now, we'll rely on the uncaught exception handler
    }
    
    private func handleUncaughtException(_ exception: NSException) {
        let crashInfo = CrashInfo(
            timestamp: Date(),
            error: NSError(domain: "UncaughtException", code: -1, userInfo: [
                NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception",
                "name": exception.name.rawValue,
                "callStack": exception.callStackSymbols
            ]),
            context: "Uncaught Exception",
            appVersion: getAppVersion(),
            systemVersion: getSystemVersion()
        )
        
        logCrashEvent("Uncaught exception: \(exception.name.rawValue)", details: crashInfo)
        incrementCrashCount()
    }
    
    private func loadCrashData() {
        // Load crash count from UserDefaults
        crashCount = UserDefaults.standard.integer(forKey: "crashCount")
        
        // Load last crash date
        if let lastCrash = UserDefaults.standard.object(forKey: "lastCrashDate") as? Date {
            lastCrashDate = lastCrash
        }
    }
    
    private func incrementCrashCount() {
        crashCount += 1
        lastCrashDate = Date()
        
        UserDefaults.standard.set(crashCount, forKey: "crashCount")
        UserDefaults.standard.set(lastCrashDate, forKey: "lastCrashDate")
    }
    
    private func logCrashEvent(_ message: String, details: Any? = nil) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        
        // Log to system
        logger.error("\(logEntry)")
        
        // Log to file
        appendToCrashLog(logEntry)
        
        if let details = details {
            let detailsString = String(describing: details)
            appendToCrashLog("Details: \(detailsString)")
        }
    }
    
    private func appendToCrashLog(_ message: String) {
        let logEntry = "\(message)\n"
        
        do {
            if FileManager.default.fileExists(atPath: crashLogPath.path) {
                // Check file size and rotate if needed
                let attributes = try FileManager.default.attributesOfItem(atPath: crashLogPath.path)
                if let fileSize = attributes[.size] as? Int, fileSize > maxCrashLogSize {
                    try FileManager.default.removeItem(at: crashLogPath)
                }
            }
            
            if FileManager.default.fileExists(atPath: crashLogPath.path) {
                let fileHandle = try FileHandle(forWritingTo: crashLogPath)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logEntry.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try logEntry.write(to: crashLogPath, atomically: true, encoding: .utf8)
            }
        } catch {
            logger.error("Failed to write to crash log: \(error.localizedDescription)")
        }
    }
    
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getSystemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

// MARK: - Data Models

private struct CrashInfo: Codable {
    let timestamp: Date
    let errorDescription: String
    let errorDomain: String
    let errorCode: Int
    let context: String
    let appVersion: String
    let systemVersion: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp, context, appVersion, systemVersion
        case errorDescription, errorDomain, errorCode
    }
    
    init(timestamp: Date, error: Error, context: String, appVersion: String, systemVersion: String) {
        self.timestamp = timestamp
        let nsError = error as NSError
        self.errorDescription = nsError.localizedDescription
        self.errorDomain = nsError.domain
        self.errorCode = nsError.code
        self.context = context
        self.appVersion = appVersion
        self.systemVersion = systemVersion
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(context, forKey: .context)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(systemVersion, forKey: .systemVersion)
        try container.encode(errorDescription, forKey: .errorDescription)
        try container.encode(errorDomain, forKey: .errorDomain)
        try container.encode(errorCode, forKey: .errorCode)
    }
}

private struct ErrorInfo: Codable {
    let timestamp: Date
    let errorDescription: String
    let errorDomain: String
    let errorCode: Int
    let context: String
    let appVersion: String
    let systemVersion: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp, context, appVersion, systemVersion
        case errorDescription, errorDomain, errorCode
    }
    
    init(timestamp: Date, error: Error, context: String, appVersion: String, systemVersion: String) {
        self.timestamp = timestamp
        let nsError = error as NSError
        self.errorDescription = nsError.localizedDescription
        self.errorDomain = nsError.domain
        self.errorCode = nsError.code
        self.context = context
        self.appVersion = appVersion
        self.systemVersion = systemVersion
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(context, forKey: .context)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(systemVersion, forKey: .systemVersion)
        try container.encode(errorDescription, forKey: .errorDescription)
        try container.encode(errorDomain, forKey: .errorDomain)
        try container.encode(errorCode, forKey: .errorCode)
    }
}

// MARK: - Signal Handlers
// Note: Signal handlers are disabled for now to avoid complexity

// MARK: - Extensions

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
