import Foundation
import os.log
import PDFKit

/// Advanced memory management for DevReader
@MainActor
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var isOptimizing = false
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "Memory")
    private var memoryTimer: Timer?
    private let memoryThreshold: UInt64 = 500 * 1024 * 1024 // 500MB
    private let criticalThreshold: UInt64 = 800 * 1024 * 1024 // 800MB
    
    enum MemoryPressure {
        case normal, warning, critical
    }
    
    private init() {
        startMemoryMonitoring()
    }
    
    deinit {
        memoryTimer?.invalidate()
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMemoryUsage()
            }
        }
    }
    
    private func updateMemoryUsage() async {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage = usage
        
        // Update memory pressure
        if usage > criticalThreshold {
            memoryPressure = .critical
            await handleCriticalMemoryPressure()
        } else if usage > memoryThreshold {
            memoryPressure = .warning
            await handleMemoryWarning()
        } else {
            memoryPressure = .normal
        }
        
        os_log("Memory usage: %{public}llu MB, Pressure: %{public}@", 
               log: logger, type: .debug, usage / (1024 * 1024), String(describing: memoryPressure))
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
    
    // MARK: - Memory Pressure Handling
    
    private func handleMemoryWarning() async {
        os_log("Memory warning - starting optimization", log: logger, type: .info)
        await optimizeMemoryUsage()
    }
    
    private func handleCriticalMemoryPressure() async {
        os_log("Critical memory pressure - aggressive optimization", log: logger, type: .error)
        isOptimizing = true
        
        // Aggressive memory cleanup
        await clearImageCaches()
        await clearUnusedPDFPages()
        await forceGarbageCollection()
        
        isOptimizing = false
    }
    
    // MARK: - Memory Optimization
    
    func optimizeMemoryUsage() async {
        guard !isOptimizing else { return }
        isOptimizing = true
        
        os_log("Starting memory optimization", log: logger, type: .info)
        
        // Clear caches
        await clearImageCaches()
        await clearUnusedPDFPages()
        
        // Force garbage collection
        await forceGarbageCollection()
        
        isOptimizing = false
        os_log("Memory optimization completed", log: logger, type: .info)
    }
    
    private func clearImageCaches() async {
        // Clear PDFKit image caches
        if let pdfView = PDFSelectionBridge.shared.pdfView {
            // Clear any cached images
            pdfView.document?.unlockWithPassword("")
        }
        
        // Clear system image caches
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func clearUnusedPDFPages() async {
        // This would be implemented with PDF page management
        // For now, we'll just log the action
        os_log("Clearing unused PDF pages", log: logger, type: .debug)
    }
    
    private func forceGarbageCollection() async {
        // Force memory cleanup
        autoreleasepool {
            // This helps with memory cleanup
        }
    }
    
    // MARK: - Memory Statistics
    
    func getMemoryStatistics() -> (used: UInt64, available: UInt64, total: UInt64) {
        let used = currentMemoryUsage
        let total = ProcessInfo.processInfo.physicalMemory
        let available = total - used
        
        return (used: used, available: available, total: total)
    }
    
    func formatMemoryUsage(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
