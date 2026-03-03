import Foundation
import os.log

// MARK: - Lightweight Logger (structured)
nonisolated enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "DevReader"
    static let pdf = OSLog(subsystem: subsystem, category: "PDF")
    static let notes = OSLog(subsystem: subsystem, category: "Notes")
    static let code = OSLog(subsystem: subsystem, category: "Code")
    static let web = OSLog(subsystem: subsystem, category: "Web")
    static let app = OSLog(subsystem: subsystem, category: "App")
    static let persistence = OSLog(subsystem: subsystem, category: "Persistence")
    static let performance = OSLog(subsystem: subsystem, category: "Performance")
    static let recovery = OSLog(subsystem: subsystem, category: "ErrorRecovery")
    static let sketch = OSLog(subsystem: subsystem, category: "Sketch")
    static let loading = OSLog(subsystem: subsystem, category: "Loading")
}

nonisolated func log(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .default, message)
}

nonisolated func logInfo(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .info, message)
}

nonisolated func logError(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .error, message)
}
