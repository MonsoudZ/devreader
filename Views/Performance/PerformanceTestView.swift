import SwiftUI
import Foundation

struct PerformanceTestView: View {
    @StateObject private var performanceMonitor = PerformanceTestMonitor()
    @State private var isRunningTests = false
    @State private var testResults: [PerformanceTestResult] = []
    @State private var selectedTest: PerformanceTestType = .largePDF
    @State private var showingResults = false
    
    enum PerformanceTestType: String, CaseIterable, Identifiable {
        case largePDF = "Large PDF Loading"
        case search = "Search Performance"
        case memory = "Memory Usage"
        case ui = "UI Responsiveness"
        case stress = "Stress Test"
        
        var id: String { self.rawValue }
        
        var description: String {
            switch self {
            case .largePDF: return "Tests loading performance with large PDF files"
            case .search: return "Tests search speed with large datasets"
            case .memory: return "Monitors memory usage during operations"
            case .ui: return "Tests UI responsiveness with many items"
            case .stress: return "Runs maximum load stress tests"
            }
        }
        
        var icon: String {
            switch self {
            case .largePDF: return "doc.text.magnifyingglass"
            case .search: return "magnifyingglass"
            case .memory: return "memorychip"
            case .ui: return "speedometer"
            case .stress: return "bolt.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Testing")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Test DevReader's performance with large PDFs and datasets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Test Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Test Type")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(PerformanceTestType.allCases) { testType in
                            TestTypeCard(
                                testType: testType,
                                isSelected: selectedTest == testType,
                                onSelect: { selectedTest = testType }
                            )
                        }
                    }
                }
                
                // Performance Monitor
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    PerformanceMetricsView(monitor: performanceMonitor)
                }
                
                // Test Controls
                VStack(spacing: 16) {
                    Button(action: runSelectedTest) {
                        HStack {
                            if isRunningTests {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isRunningTests ? "Running Test..." : "Run Test")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedTest.color)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isRunningTests)
                    
                    if !testResults.isEmpty {
                        Button("View Results") {
                            showingResults = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Performance Testing")
            .sheet(isPresented: $showingResults) {
                PerformanceResultsView(results: testResults)
            }
        }
    }
    
    private func runSelectedTest() {
        isRunningTests = true
        
        Task {
            let result = await performanceMonitor.runTest(selectedTest)
            
            await MainActor.run {
                testResults.append(result)
                isRunningTests = false
            }
        }
    }
}

// MARK: - Test Type Card

struct TestTypeCard: View {
    let testType: PerformanceTestView.PerformanceTestType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: testType.icon)
                        .font(.title2)
                        .foregroundStyle(testType.color)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                Text(testType.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(testType.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(isSelected ? testType.color.opacity(0.1) : Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? testType.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Performance Metrics View

struct PerformanceMetricsView: View {
    @ObservedObject var monitor: PerformanceTestMonitor
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                MetricCard(
                    title: "Memory Usage",
                    value: monitor.memoryUsage,
                    unit: "MB",
                    color: monitor.memoryUsage > 500 ? .red : .green
                )
                
                MetricCard(
                    title: "CPU Usage",
                    value: monitor.cpuUsage,
                    unit: "%",
                    color: monitor.cpuUsage > 80 ? .red : .green
                )
            }
            
            HStack {
                MetricCard(
                    title: "Load Time",
                    value: monitor.averageLoadTime,
                    unit: "s",
                    color: monitor.averageLoadTime > 5 ? .red : .green
                )
                
                MetricCard(
                    title: "Search Speed",
                    value: monitor.averageSearchTime,
                    unit: "s",
                    color: monitor.averageSearchTime > 2 ? .red : .green
                )
            }
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Performance Monitor

@MainActor
class PerformanceTestMonitor: ObservableObject {
    @Published var memoryUsage: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var averageLoadTime: Double = 0
    @Published var averageSearchTime: Double = 0
    
    private var loadTimes: [Double] = []
    private var searchTimes: [Double] = []
    private var monitoringTimer: Timer?

    init() {
        startMonitoring()
    }

    deinit {
        monitoringTimer?.invalidate()
    }

    private func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        // Update memory usage
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = Double(memoryInfo.resident_size) / 1024 / 1024 // Convert to MB
        }
        
        // Update CPU usage via thread_info
        cpuUsage = getCPUUsage()
    }
    
    func runTest(_ testType: PerformanceTestView.PerformanceTestType) async -> PerformanceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        switch testType {
        case .largePDF:
            await simulateLargePDFTest()
        case .search:
            await simulateSearchTest()
        case .memory:
            await simulateMemoryTest()
        case .ui:
            await simulateUITest()
        case .stress:
            await simulateStressTest()
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        let result = PerformanceTestResult(
            testType: testType,
            duration: duration,
            memoryUsage: memoryUsage,
            success: duration < getThreshold(for: testType)
        )
        
        // Update averages
        if testType == .largePDF {
            loadTimes.append(duration)
            averageLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        } else if testType == .search {
            searchTimes.append(duration)
            averageSearchTime = searchTimes.reduce(0, +) / Double(searchTimes.count)
        }
        
        return result
    }
    
    private func getThreshold(for testType: PerformanceTestView.PerformanceTestType) -> Double {
        switch testType {
        case .largePDF: return 10.0
        case .search: return 3.0
        case .memory: return 5.0
        case .ui: return 2.0
        case .stress: return 15.0
        }
    }
    
    private func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.size))
        }
        var totalUsage: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            if kr == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }
        return min(totalUsage, 100)
    }

    private func simulateLargePDFTest() async {
        // Allocate and process a large data buffer to stress memory/CPU
        await Task.detached(priority: .userInitiated) {
            var data = Data(count: 50 * 1024 * 1024) // 50 MB
            data.withUnsafeMutableBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for i in 0..<buffer.count { ptr[i] = UInt8(i & 0xFF) }
            }
        }.value
    }

    private func simulateSearchTest() async {
        // Search through a large array of random strings
        await Task.detached(priority: .userInitiated) {
            let strings = (0..<100_000).map { "item_\($0)_\(UUID().uuidString)" }
            for query in ["item_50000", "item_99999", "nonexistent"] {
                _ = strings.filter { $0.contains(query) }
            }
        }.value
    }

    private func simulateMemoryTest() async {
        // Allocate and release memory in waves to measure memory handling
        await Task.detached(priority: .userInitiated) {
            var buffers: [Data] = []
            for _ in 0..<10 {
                buffers.append(Data(count: 10 * 1024 * 1024)) // 10 MB each
            }
            buffers.removeAll()
        }.value
    }

    private func simulateUITest() async {
        // Sort a large array repeatedly to measure responsiveness
        await Task.detached(priority: .userInitiated) {
            var array = (0..<500_000).map { _ in Int.random(in: 0..<1_000_000) }
            array.sort()
            array.sort { $0 > $1 }
        }.value
    }

    private func simulateStressTest() async {
        // Run all operations concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.simulateLargePDFTest() }
            group.addTask { await self.simulateSearchTest() }
            group.addTask { await self.simulateMemoryTest() }
            group.addTask { await self.simulateUITest() }
        }
    }
}

// MARK: - Performance Test Result

struct PerformanceTestResult: Identifiable {
    let id = UUID()
    let testType: PerformanceTestView.PerformanceTestType
    let duration: Double
    let memoryUsage: Double
    let success: Bool
    let timestamp = Date()
}

// MARK: - Performance Results View

struct PerformanceResultsView: View {
    let results: [PerformanceTestResult]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: result.testType.icon)
                                .foregroundStyle(result.testType.color)
                            
                            Text(result.testType.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)
                        }
                        
                        HStack {
                            Text("Duration: \(String(format: "%.2f", result.duration))s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Memory: \(String(format: "%.1f", result.memoryUsage))MB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Completed: \(result.timestamp.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Extensions

extension PerformanceTestView.PerformanceTestType {
    var color: Color {
        switch self {
        case .largePDF: return .blue
        case .search: return .orange
        case .memory: return .purple
        case .ui: return .green
        case .stress: return .red
        }
    }
}

#Preview {
    PerformanceTestView()
}
