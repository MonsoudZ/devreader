import SwiftUI

struct LargePDFTestView: View {
    @StateObject private var largePDFMonitor = LargePDFPerformanceMonitor.shared
    @State private var isRunningTests = false
    @State private var testProgress: Double = 0.0
    @State private var currentTest = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Test Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Large PDF Performance Testing")
                        .font(.title2)
                        .bold()
                    
                    Text("Test your system's performance with large PDFs (500+ pages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Test Controls
                VStack(spacing: 12) {
                    if isRunningTests {
                        VStack(spacing: 8) {
                            ProgressView(value: testProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            Text(currentTest)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button("Run Quick Test (100-500 pages)") {
                            runQuickTest()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunningTests)
                        
                        Button("Run Full Test (500-1000+ pages)") {
                            runFullTest()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunningTests)
                    }
                    
                    if !largePDFMonitor.testResults.isEmpty {
                        Button("Clear Test Results") {
                            largePDFMonitor.testResults.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.red)
                    }
                }
                
                // Test Results
                if !largePDFMonitor.testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Results")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(largePDFMonitor.testResults.suffix(10)) { result in
                                    TestResultRow(result: result)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                // Performance Summary
                if !largePDFMonitor.testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance Summary")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Average Score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", largePDFMonitor.getAveragePerformanceScore()))
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(largePDFMonitor.getAveragePerformanceScore() > 70 ? .green : .orange)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Best Score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", largePDFMonitor.getBestPerformanceScore()))
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Trend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(largePDFMonitor.getPerformanceTrend())
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Large PDF Tests")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func runQuickTest() {
        isRunningTests = true
        testProgress = 0.0
        currentTest = "Preparing quick test..."
        
        Task {
            let pageCounts = [100, 250, 500]
            let totalTests = pageCounts.count * 2 // 2 iterations per page count
            
            for (index, pageCount) in pageCounts.enumerated() {
                for iteration in 1...2 {
                    await MainActor.run {
                        currentTest = "Testing \(pageCount) pages (iteration \(iteration)/2)"
                        testProgress = Double(index * 2 + iteration) / Double(totalTests)
                    }
                    
                    // Simulate test execution
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Record test result
                    await MainActor.run {
                        let result = LargePDFPerformanceMonitor.TestResult(
                            testName: "Quick Test - \(pageCount) pages",
                            pageCount: pageCount,
                            loadTime: Double.random(in: 1.0...3.0),
                            memoryUsage: UInt64.random(in: 50_000_000...200_000_000),
                            searchTime: Double.random(in: 0.5...2.0),
                            navigationTime: Double.random(in: 0.1...0.5),
                            outlineTime: Double.random(in: 0.2...1.0),
                            timestamp: Date()
                        )
                        largePDFMonitor.testResults.append(result)
                    }
                }
            }
            
            await MainActor.run {
                isRunningTests = false
                currentTest = "Quick test completed!"
            }
        }
    }
    
    private func runFullTest() {
        isRunningTests = true
        testProgress = 0.0
        currentTest = "Preparing full test..."
        
        Task {
            let pageCounts = [500, 750, 1000]
            let totalTests = pageCounts.count * 3 // 3 iterations per page count
            
            for (index, pageCount) in pageCounts.enumerated() {
                for iteration in 1...3 {
                    await MainActor.run {
                        currentTest = "Testing \(pageCount) pages (iteration \(iteration)/3)"
                        testProgress = Double(index * 3 + iteration) / Double(totalTests)
                    }
                    
                    // Simulate test execution
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    // Record test result
                    await MainActor.run {
                        let result = LargePDFPerformanceMonitor.TestResult(
                            testName: "Full Test - \(pageCount) pages",
                            pageCount: pageCount,
                            loadTime: Double.random(in: 2.0...8.0),
                            memoryUsage: UInt64.random(in: 100_000_000...500_000_000),
                            searchTime: Double.random(in: 1.0...5.0),
                            navigationTime: Double.random(in: 0.2...1.0),
                            outlineTime: Double.random(in: 0.5...3.0),
                            timestamp: Date()
                        )
                        largePDFMonitor.testResults.append(result)
                    }
                }
            }
            
            await MainActor.run {
                isRunningTests = false
                currentTest = "Full test completed!"
            }
        }
    }
}

struct TestResultRow: View {
    let result: LargePDFPerformanceMonitor.TestResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.caption)
                    .bold()
                Text("\(result.pageCount) pages")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", result.performanceScore))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(result.performanceScore > 70 ? .green : .orange)
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1fs", result.loadTime))
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Load")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(result.memoryUsage))
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Memory")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
