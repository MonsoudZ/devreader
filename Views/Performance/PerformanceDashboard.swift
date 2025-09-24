import SwiftUI
import Charts

/// Real-time performance monitoring dashboard
struct PerformanceDashboard: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @State private var showingAlerts = false
    @State private var refreshRate: Double = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Performance Monitor")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(monitor.isMonitoring ? "Stop" : "Start") {
                    if monitor.isMonitoring {
                        monitor.stopMonitoring()
                    } else {
                        monitor.startMonitoring()
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Clear Stats") {
                    monitor.clearStatistics()
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    // Memory Usage Card
                    memoryUsageCard
                    
                    // Performance Metrics Card
                    performanceMetricsCard
                    
                    // System Resources Card
                    systemResourcesCard
                    
                    // Alerts Card
                    alertsCard
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if !monitor.isMonitoring {
                monitor.startMonitoring()
            }
        }
    }
    
    // MARK: - Memory Usage Card
    
    private var memoryUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Usage")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monitor.formatBytes(monitor.memoryUsage))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Peak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monitor.formatBytes(monitor.peakMemoryUsage))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monitor.formatBytes(monitor.averageMemoryUsage))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Memory pressure indicator
                HStack {
                    Circle()
                        .fill(memoryPressureColor)
                        .frame(width: 12, height: 12)
                    Text(memoryPressureText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Memory usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(memoryPressureColor)
                        .frame(width: memoryUsageWidth(geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Performance Metrics Card
    
    private var performanceMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                MetricView(
                    title: "Frame Rate",
                    value: String(format: "%.1f FPS", monitor.frameRate),
                    color: frameRateColor
                )
                
                MetricView(
                    title: "CPU Usage",
                    value: String(format: "%.1f%%", monitor.cpuUsage),
                    color: cpuUsageColor
                )
                
                MetricView(
                    title: "Operations",
                    value: "\(monitor.totalOperations)",
                    color: .blue
                )
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Operation Times")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("PDF Load")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(monitor.formatDuration(monitor.pdfLoadTime))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Search")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(monitor.formatDuration(monitor.searchTime))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Annotation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(monitor.formatDuration(monitor.annotationTime))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - System Resources Card
    
    private var systemResourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Resources")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Available Memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(availableMemoryText)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Memory Efficiency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(memoryEfficiencyText)
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Alerts Card
    
    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Alerts")
                    .font(.headline)
                
                Spacer()
                
                if !monitor.performanceAlerts.isEmpty {
                    Button("View All") {
                        showingAlerts = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if monitor.performanceAlerts.isEmpty {
                Text("No performance alerts")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(monitor.performanceAlerts.suffix(5)) { alert in
                        AlertRow(alert: alert)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .sheet(isPresented: $showingAlerts) {
            AlertsView(alerts: monitor.performanceAlerts)
        }
    }
    
    // MARK: - Computed Properties
    
    private var memoryPressureColor: Color {
        switch monitor.memoryPressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private var memoryPressureText: String {
        switch monitor.memoryPressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
    
    private var frameRateColor: Color {
        if monitor.frameRate >= 60 { return .green }
        else if monitor.frameRate >= 30 { return .orange }
        else { return .red }
    }
    
    private var cpuUsageColor: Color {
        if monitor.cpuUsage < 50 { return .green }
        else if monitor.cpuUsage < 80 { return .orange }
        else { return .red }
    }
    
    private var availableMemoryText: String {
        let total = ProcessInfo.processInfo.physicalMemory
        let available = total - monitor.memoryUsage
        return monitor.formatBytes(available)
    }
    
    private var memoryEfficiencyText: String {
        let total = ProcessInfo.processInfo.physicalMemory
        let percentage = Double(monitor.memoryUsage) / Double(total) * 100
        return String(format: "%.1f%% used", percentage)
    }
    
    private func memoryUsageWidth(_ totalWidth: CGFloat) -> CGFloat {
        let total = ProcessInfo.processInfo.physicalMemory
        let percentage = Double(monitor.memoryUsage) / Double(total)
        return totalWidth * CGFloat(percentage)
    }
}

// MARK: - Supporting Views

struct MetricView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AlertRow: View {
    let alert: PerformanceMonitor.PerformanceAlert
    
    var body: some View {
        HStack {
            Circle()
                .fill(alertColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.body)
                Text(alert.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var alertColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct AlertsView: View {
    let alerts: [PerformanceMonitor.PerformanceAlert]
    
    var body: some View {
        NavigationView {
            List(alerts.reversed()) { alert in
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.message)
                        .font(.body)
                    HStack {
                        Text(alert.timestamp, style: .date)
                        Text(alert.timestamp, style: .time)
                        Spacer()
                        Text(alert.severityText)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(alert.severityColor)
                            .cornerRadius(4)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Performance Alerts")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(width: 500, height: 400)
    }
}

extension PerformanceMonitor.PerformanceAlert {
    var severityText: String {
        switch severity {
        case .info: return "Info"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
    
    var severityColor: Color {
        switch severity {
        case .info: return .blue.opacity(0.2)
        case .warning: return .orange.opacity(0.2)
        case .critical: return .red.opacity(0.2)
        }
    }
}
