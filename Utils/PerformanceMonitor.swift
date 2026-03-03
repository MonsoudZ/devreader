import Foundation
import Combine
import os.log

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published var memoryUsage: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var isMonitoring = false

    // Performance metrics
    @Published var pdfLoadTime: TimeInterval = 0.0
    @Published var searchTime: TimeInterval = 0.0
    @Published var annotationTime: TimeInterval = 0.0

    // Memory statistics
    @Published var peakMemoryUsage: UInt64 = 0
    @Published var averageMemoryUsage: UInt64 = 0

    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "Performance")
    private var monitoringTimer: Timer?
    private var memoryHistory: [UInt64] = []
    private let maxHistorySize = 50
    private let memoryThreshold: UInt64 = 500 * 1024 * 1024 // 500MB
    private let criticalThreshold: UInt64 = 800 * 1024 * 1024 // 800MB

    enum MemoryPressure {
        case normal, warning, critical
    }

    private init() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }

        os_log("Performance monitoring started", log: logger, type: .info)
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil

        os_log("Performance monitoring stopped", log: logger, type: .info)
    }

    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        memoryUsage = usage

        memoryHistory.append(usage)
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }

        averageMemoryUsage = memoryHistory.reduce(0, +) / UInt64(memoryHistory.count)

        if usage > peakMemoryUsage {
            peakMemoryUsage = usage
        }

        if usage > criticalThreshold {
            memoryPressure = .critical
            os_log("Critical memory pressure - aggressive optimization", log: logger, type: .error)
            URLCache.shared.removeAllCachedResponses()
        } else if usage > memoryThreshold {
            memoryPressure = .warning
            os_log("Memory warning - starting optimization", log: logger, type: .info)
            URLCache.shared.removeAllCachedResponses()
        } else {
            memoryPressure = .normal
        }
    }

    // MARK: - Performance Tracking

    func trackPDFLoad(_ startTime: Date) {
        let loadTime = Date().timeIntervalSince(startTime)
        pdfLoadTime = loadTime
        os_log("PDF load time: %{public}.2f seconds", log: logger, type: .info, loadTime)
    }

    func trackSearch(_ startTime: Date) {
        let searchTime = Date().timeIntervalSince(startTime)
        self.searchTime = searchTime
        os_log("Search time: %{public}.2f seconds", log: logger, type: .info, searchTime)
    }

    func trackAnnotation(_ startTime: Date) {
        let annotationTime = Date().timeIntervalSince(startTime)
        self.annotationTime = annotationTime
        os_log("Annotation time: %{public}.2f seconds", log: logger, type: .info, annotationTime)
    }

    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        return 0
    }

    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    func getMemoryPressure() -> String {
        let total = ProcessInfo.processInfo.physicalMemory
        let percentage = Double(memoryUsage) / Double(total) * 100

        if percentage > 80 {
            return "Critical"
        } else if percentage > 60 {
            return "Warning"
        } else {
            return "Normal"
        }
    }
}
