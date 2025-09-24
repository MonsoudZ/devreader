import Foundation
import os.log

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "DevReader"
    static let pdf = OSLog(subsystem: subsystem, category: "PDF")
    static let notes = OSLog(subsystem: subsystem, category: "Notes")
    static let app = OSLog(subsystem: subsystem, category: "App")
}

func log(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .default, message)
}

func logError(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .error, message)
}


