import Foundation
import Combine
import os.log

// MARK: - Large PDF Performance Monitor
@MainActor
class LargePDFPerformanceMonitor: ObservableObject {
    static let shared = LargePDFPerformanceMonitor()
    
    @Published var isMonitoring = false
    @Published var currentTest: String = ""
    @Published var testResults: [TestResult] = []
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "LargePDFPerformance")
    private var monitoringTimer: Timer?
    
    struct TestResult: Identifiable, Codable {
        let id = UUID()
        let testName: String
        let pageCount: Int
        let loadTime: TimeInterval
        let memoryUsage: UInt64
        let searchTime: TimeInterval?
        let navigationTime: TimeInterval?
        let outlineTime: TimeInterval?
        let timestamp: Date
        
        var performanceScore: Double {
            // Calculate a performance score based on various metrics
            let loadScore = max(0, 100 - (loadTime * 10)) // Penalty for slow loading
            let memoryScore = max(0, 100 - (Double(memoryUsage) / (1024 * 1024 * 1024) * 50)) // Penalty for high memory
            let searchScore = searchTime.map { max(0, 100 - ($0 * 20)) } ?? 50 // Penalty for slow search
            let navScore = navigationTime.map { max(0, 100 - ($0 * 100)) } ?? 50 // Penalty for slow navigation
            
            return (loadScore + memoryScore + (searchScore ?? 50) + (navScore ?? 50)) / 4
        }
    }
    
    private init() {}
    
    // MARK: - Monitoring Control
    
    func startMonitoring(_ testName: String) {
        isMonitoring = true
        currentTest = testName
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.logCurrentStatus()
            }
        }
        
        os_log("Started large PDF performance monitoring: %{public}@", log: logger, type: .info, testName)
    }
    
    func stopMonitoring() {
        isMonitoring = false
        currentTest = ""
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        os_log("Stopped large PDF performance monitoring", log: logger, type: .info)
    }
    
    // MARK: - Test Recording
    
    func recordTestResult(
        testName: String,
        pageCount: Int,
        loadTime: TimeInterval,
        memoryUsage: UInt64,
        searchTime: TimeInterval? = nil,
        navigationTime: TimeInterval? = nil,
        outlineTime: TimeInterval? = nil
    ) {
        let result = TestResult(
            testName: testName,
            pageCount: pageCount,
            loadTime: loadTime,
            memoryUsage: memoryUsage,
            searchTime: searchTime,
            navigationTime: navigationTime,
            outlineTime: outlineTime,
            timestamp: Date()
        )
        
        testResults.append(result)
        
        // Keep only last 100 results
        if testResults.count > 100 {
            testResults.removeFirst(testResults.count - 100)
        }
        
        os_log("Recorded test result: %{public}@ - Score: %.1f", log: logger, type: .info, testName, result.performanceScore)
    }
    
    // MARK: - Performance Analysis
    
    func getAveragePerformanceScore() -> Double {
        guard !testResults.isEmpty else { return 0 }
        return testResults.map { $0.performanceScore }.reduce(0, +) / Double(testResults.count)
    }
    
    func getBestPerformanceScore() -> Double {
        return testResults.map { $0.performanceScore }.max() ?? 0
    }
    
    func getWorstPerformanceScore() -> Double {
        return testResults.map { $0.performanceScore }.min() ?? 0
    }
    
    func getPerformanceTrend() -> String {
        guard testResults.count >= 3 else { return "Insufficient data" }
        
        let recent = testResults.suffix(3)
        let older = testResults.prefix(3)
        
        let recentAvg = recent.map { $0.performanceScore }.reduce(0, +) / Double(recent.count)
        let olderAvg = older.map { $0.performanceScore }.reduce(0, +) / Double(older.count)
        
        if recentAvg > olderAvg + 5 {
            return "Improving"
        } else if recentAvg < olderAvg - 5 {
            return "Declining"
        } else {
            return "Stable"
        }
    }
    
    // MARK: - Memory Analysis
    
    func getMemoryUsageStats() -> (average: UInt64, peak: UInt64, trend: String) {
        guard !testResults.isEmpty else { return (0, 0, "No data") }
        
        let memoryUsages = testResults.map { $0.memoryUsage }
        let average = memoryUsages.reduce(0, +) / UInt64(memoryUsages.count)
        let peak = memoryUsages.max() ?? 0
        
        let trend: String
        if testResults.count >= 3 {
            let recent = testResults.suffix(3).map { $0.memoryUsage }
            let older = testResults.prefix(3).map { $0.memoryUsage }
            
            let recentAvg = recent.reduce(0, +) / UInt64(recent.count)
            let olderAvg = older.reduce(0, +) / UInt64(older.count)
            
            if recentAvg > olderAvg + (50 * 1024 * 1024) { // 50MB increase
                trend = "Increasing"
            } else if recentAvg < olderAvg - (50 * 1024 * 1024) { // 50MB decrease
                trend = "Decreasing"
            } else {
                trend = "Stable"
            }
        } else {
            trend = "Insufficient data"
        }
        
        return (average, peak, trend)
    }
    
    // MARK: - Load Time Analysis
    
    func getLoadTimeStats() -> (average: TimeInterval, fastest: TimeInterval, slowest: TimeInterval) {
        guard !testResults.isEmpty else { return (0, 0, 0) }
        
        let loadTimes = testResults.map { $0.loadTime }
        let average = loadTimes.reduce(0, +) / Double(loadTimes.count)
        let fastest = loadTimes.min() ?? 0
        let slowest = loadTimes.max() ?? 0
        
        return (average, fastest, slowest)
    }
    
    // MARK: - Recommendations
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let memoryStats = getMemoryUsageStats()
        let loadStats = getLoadTimeStats()
        let avgScore = getAveragePerformanceScore()
        
        // Memory recommendations
        if memoryStats.average > 500 * 1024 * 1024 { // 500MB
            recommendations.append("Consider implementing more aggressive memory management for large PDFs")
        }
        
        if memoryStats.trend == "Increasing" {
            recommendations.append("Memory usage is increasing - check for memory leaks")
        }
        
        // Load time recommendations
        if loadStats.average > 5.0 {
            recommendations.append("PDF loading is slow - consider implementing progressive loading")
        }
        
        if loadStats.slowest > 10.0 {
            recommendations.append("Some PDFs are loading very slowly - optimize PDF processing")
        }
        
        // Overall performance recommendations
        if avgScore < 70 {
            recommendations.append("Overall performance is below optimal - review all performance metrics")
        }
        
        if avgScore < 50 {
            recommendations.append("Performance is poor - consider major optimizations")
        }
        
        return recommendations
    }
    
    // MARK: - Export Results
    
    func exportTestResults() -> String {
        var report = "# Large PDF Performance Report\n\n"
        report += "Generated: \(Date())\n"
        report += "Total Tests: \(testResults.count)\n\n"
        
        // Summary
        report += "## Performance Summary\n"
        report += "- Average Score: \(String(format: "%.1f", getAveragePerformanceScore()))\n"
        report += "- Best Score: \(String(format: "%.1f", getBestPerformanceScore()))\n"
        report += "- Worst Score: \(String(format: "%.1f", getWorstPerformanceScore()))\n"
        report += "- Trend: \(getPerformanceTrend())\n\n"
        
        // Memory stats
        let memoryStats = getMemoryUsageStats()
        report += "## Memory Usage\n"
        report += "- Average: \(formatBytes(memoryStats.average))\n"
        report += "- Peak: \(formatBytes(memoryStats.peak))\n"
        report += "- Trend: \(memoryStats.trend)\n\n"
        
        // Load time stats
        let loadStats = getLoadTimeStats()
        report += "## Load Times\n"
        report += "- Average: \(String(format: "%.2f", loadStats.average))s\n"
        report += "- Fastest: \(String(format: "%.2f", loadStats.fastest))s\n"
        report += "- Slowest: \(String(format: "%.2f", loadStats.slowest))s\n\n"
        
        // Recommendations
        let recommendations = getPerformanceRecommendations()
        if !recommendations.isEmpty {
            report += "## Recommendations\n"
            for recommendation in recommendations {
                report += "- \(recommendation)\n"
            }
            report += "\n"
        }
        
        // Detailed results
        report += "## Detailed Results\n"
        for result in testResults.suffix(10) { // Last 10 results
            report += "### \(result.testName)\n"
            report += "- Pages: \(result.pageCount)\n"
            report += "- Load Time: \(String(format: "%.2f", result.loadTime))s\n"
            report += "- Memory: \(formatBytes(result.memoryUsage))\n"
            report += "- Score: \(String(format: "%.1f", result.performanceScore))\n"
            report += "- Date: \(result.timestamp)\n\n"
        }
        
        return report
    }
    
    // MARK: - Helper Methods
    
    private func logCurrentStatus() {
        let memoryUsage = getCurrentMemoryUsage()
        os_log("Large PDF Test Status - Test: %{public}@, Memory: %{public}@", 
               log: logger, type: .debug, currentTest, formatBytes(memoryUsage))
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
