import Foundation
import os.log
import SwiftUI

/// Real-time performance monitoring and memory tracking
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var memoryUsage: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var cpuUsage: Double = 0.0
    @Published var frameRate: Double = 0.0
    @Published var isMonitoring = false
    
    // Performance metrics
    @Published var pdfLoadTime: TimeInterval = 0.0
    @Published var searchTime: TimeInterval = 0.0
    @Published var annotationTime: TimeInterval = 0.0
    @Published var totalOperations: Int = 0
    
    // Memory statistics
    @Published var peakMemoryUsage: UInt64 = 0
    @Published var averageMemoryUsage: UInt64 = 0
    @Published var memoryLeaks: Int = 0
    
    // Performance alerts
    @Published var performanceAlerts: [PerformanceAlert] = []
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "Performance")
    private var monitoringTimer: Timer?
    private var frameCount = 0
    private var lastFrameTime = Date()
    private var memoryHistory: [UInt64] = []
    private let maxHistorySize = 100
    
    enum MemoryPressure {
        case normal, warning, critical
    }
    
    struct PerformanceAlert: Identifiable {
        let id = UUID()
        let type: AlertType
        let message: String
        let timestamp: Date
        let severity: Severity
        
        enum AlertType {
            case highMemoryUsage
            case lowFrameRate
            case slowOperation
            case memoryLeak
        }
        
        enum Severity {
            case info, warning, critical
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
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
    
    // MARK: - Metrics Update
    
    private func updateMetrics() async {
        await updateMemoryUsage()
        await updateCPUUsage()
        await updateFrameRate()
        await checkPerformanceThresholds()
    }
    
    private func updateMemoryUsage() async {
        let usage = getCurrentMemoryUsage()
        memoryUsage = usage
        
        // Update memory history
        memoryHistory.append(usage)
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
        
        // Calculate average
        averageMemoryUsage = memoryHistory.reduce(0, +) / UInt64(memoryHistory.count)
        
        // Update peak
        if usage > peakMemoryUsage {
            peakMemoryUsage = usage
        }
        
        // Determine memory pressure
        let threshold: UInt64 = 500 * 1024 * 1024 // 500MB
        let criticalThreshold: UInt64 = 800 * 1024 * 1024 // 800MB
        
        if usage > criticalThreshold {
            memoryPressure = .critical
        } else if usage > threshold {
            memoryPressure = .warning
        } else {
            memoryPressure = .normal
        }
    }
    
    private func updateCPUUsage() async {
        // Simplified CPU usage calculation
        // In a real implementation, you'd use more sophisticated methods
        cpuUsage = Double.random(in: 0...100) // Placeholder
    }
    
    private func updateFrameRate() async {
        frameCount += 1
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastFrameTime)
        
        if timeDelta >= 1.0 {
            frameRate = Double(frameCount) / timeDelta
            frameCount = 0
            lastFrameTime = now
        }
    }
    
    private func checkPerformanceThresholds() async {
        // Check for performance issues
        if memoryUsage > 800 * 1024 * 1024 { // 800MB
            addAlert(.highMemoryUsage, "High memory usage: \(formatBytes(memoryUsage))", .warning)
        }
        
        if frameRate < 30 && frameRate > 0 {
            addAlert(.lowFrameRate, "Low frame rate: \(String(format: "%.1f", frameRate)) FPS", .warning)
        }
    }
    
    // MARK: - Performance Tracking
    
    func trackOperation<T>(_ operation: () throws -> T, name: String) rethrows -> T {
        let startTime = Date()
        totalOperations += 1
        
        defer {
            let duration = Date().timeIntervalSince(startTime)
            logOperation(name, duration: duration)
            
            if duration > 1.0 {
                addAlert(.slowOperation, "Slow operation: \(name) took \(String(format: "%.2f", duration))s", .warning)
            }
        }
        
        return try operation()
    }
    
    func trackPDFLoad(_ operation: @escaping () async throws -> Void) async throws {
        let startTime = Date()
        
        defer {
            pdfLoadTime = Date().timeIntervalSince(startTime)
            os_log("PDF load time: %{public}@ seconds", log: logger, type: .info, String(pdfLoadTime))
        }
        
        try await operation()
    }
    
    func trackSearch(_ operation: @escaping () async throws -> Void) async throws {
        let startTime = Date()
        
        defer {
            searchTime = Date().timeIntervalSince(startTime)
            os_log("Search time: %{public}@ seconds", log: logger, type: .info, String(searchTime))
        }
        
        try await operation()
    }
    
    func trackAnnotation(_ operation: @escaping () async throws -> Void) async throws {
        let startTime = Date()
        
        defer {
            annotationTime = Date().timeIntervalSince(startTime)
            os_log("Annotation time: %{public}@ seconds", log: logger, type: .info, String(annotationTime))
        }
        
        try await operation()
    }
    
    // MARK: - Memory Management
    
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
    
    // MARK: - Alerts
    
    private func addAlert(_ type: PerformanceAlert.AlertType, _ message: String, _ severity: PerformanceAlert.Severity) {
        let alert = PerformanceAlert(
            type: type,
            message: message,
            timestamp: Date(),
            severity: severity
        )
        
        performanceAlerts.append(alert)
        
        // Keep only recent alerts
        if performanceAlerts.count > 50 {
            performanceAlerts.removeFirst(performanceAlerts.count - 50)
        }
        
        os_log("Performance alert: %{public}@", log: logger, type: .info, message)
    }
    
    private func logOperation(_ name: String, duration: TimeInterval) {
        os_log("Operation '%{public}@' took %{public}@ seconds", log: logger, type: .debug, name, String(duration))
    }
    
    // MARK: - Statistics
    
    func getPerformanceStatistics() -> PerformanceStatistics {
        return PerformanceStatistics(
            memoryUsage: memoryUsage,
            peakMemoryUsage: peakMemoryUsage,
            averageMemoryUsage: averageMemoryUsage,
            cpuUsage: cpuUsage,
            frameRate: frameRate,
            totalOperations: totalOperations,
            pdfLoadTime: pdfLoadTime,
            searchTime: searchTime,
            annotationTime: annotationTime,
            alertCount: performanceAlerts.count
        )
    }
    
    func clearStatistics() {
        peakMemoryUsage = 0
        averageMemoryUsage = 0
        memoryHistory.removeAll()
        performanceAlerts.removeAll()
        totalOperations = 0
        pdfLoadTime = 0
        searchTime = 0
        annotationTime = 0
    }
    
    // MARK: - Utility Functions
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1.0 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

// MARK: - Performance Statistics

struct PerformanceStatistics {
    let memoryUsage: UInt64
    let peakMemoryUsage: UInt64
    let averageMemoryUsage: UInt64
    let cpuUsage: Double
    let frameRate: Double
    let totalOperations: Int
    let pdfLoadTime: TimeInterval
    let searchTime: TimeInterval
    let annotationTime: TimeInterval
    let alertCount: Int
}
