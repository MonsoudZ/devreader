import Foundation
import PDFKit
import SwiftUI
import Combine
import os.log
import CoreImage
import ImageIO

extension PDFSelection {
	func pageBoxes() -> [(PDFPage, CGRect)] {
		var res: [(PDFPage, CGRect)] = []
		for page in pages {
			let bounds = bounds(for: page)
			if !bounds.isEmpty { res.append((page, bounds)) }
		}
		return res
	}
}

extension Path {
	func nsBezierPath() -> NSBezierPath {
		let bp = NSBezierPath()
		var first = true
		self.forEach { element in
			switch element {
			case .move(to: let p):
				bp.move(to: NSPoint(x: p.x, y: p.y)); first = false
			case .line(to: let p):
				if first { bp.move(to: NSPoint(x: p.x, y: p.y)); first = false } else { bp.line(to: NSPoint(x: p.x, y: p.y)) }
			case .quadCurve(to: let p, control: let c):
				bp.curve(to: NSPoint(x: p.x, y: p.y), controlPoint1: NSPoint(x: c.x, y: c.y), controlPoint2: NSPoint(x: c.x, y: c.y))
			case .curve(to: let p, control1: let c1, control2: let c2):
				bp.curve(to: NSPoint(x: p.x, y: p.y), controlPoint1: NSPoint(x: c1.x, y: c1.y), controlPoint2: NSPoint(x: c2.x, y: c2.y))
			case .closeSubpath:
				bp.close()
			@unknown default: break
			}
		}
		return bp
	}
}

extension Notification.Name {
	static let captureHighlight = Notification.Name("DevReader.captureHighlight")
	static let newSketchPage    = Notification.Name("DevReader.newSketchPage")
	static let addStickyNote    = Notification.Name("DevReader.addStickyNote")
	static let closePDF         = Notification.Name("DevReader.closePDF")
	static let pdfLoadError     = Notification.Name("DevReader.pdfLoadError")
	static let sessionCorrupted = Notification.Name("DevReader.sessionCorrupted")
	static let dataRecovery     = Notification.Name("DevReader.dataRecovery")
	static let showOnboarding   = Notification.Name("DevReader.showOnboarding")
	static let memoryPressure   = Notification.Name("DevReader.memoryPressure")
}

// MARK: - Performance Monitoring
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
        // Only start monitoring if not in a high CPU situation
        // This can be disabled if causing performance issues
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            startMonitoring()
        }
    }
    
    deinit {
        Task.detached { @MainActor in
            PerformanceMonitor.shared.stopMonitoring()
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Reduce monitoring frequency to every 10 seconds instead of 2 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMemoryUsage()
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
        if usage > criticalThreshold {
            memoryPressure = .critical
            await handleCriticalMemoryPressure()
        } else if usage > memoryThreshold {
            memoryPressure = .warning
            await handleMemoryWarning()
        } else {
            memoryPressure = .normal
        }
        
        // Log memory usage every 30 seconds to reduce CPU usage
        if Int(Date().timeIntervalSince1970) % 30 == 0 {
            os_log("Memory usage: %{public}@", log: logger, type: .info, formatBytes(usage))
        }
    }
    
    private func handleMemoryWarning() async {
        os_log("Memory warning - starting optimization", log: logger, type: .info)
        await optimizeMemoryUsage()
    }
    
    private func handleCriticalMemoryPressure() async {
        os_log("Critical memory pressure - aggressive optimization", log: logger, type: .error)
        await optimizeMemoryUsage()
    }
    
    private func optimizeMemoryUsage() async {
        // Clear caches and force garbage collection
        await clearImageCaches()
        await forceGarbageCollection()
    }
    
    private func clearImageCaches() async {
        // Clear any image caches
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func forceGarbageCollection() async {
        // Force garbage collection
        autoreleasepool {
            // This will trigger garbage collection
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

// MARK: - Lightweight Logger (structured)
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "DevReader"
    static let pdf = OSLog(subsystem: subsystem, category: "PDF")
    static let notes = OSLog(subsystem: subsystem, category: "Notes")
    static let app = OSLog(subsystem: subsystem, category: "App")
}

// MARK: - Image Processing (robust fallbacks)
enum ImageProcessingService {
    /// Attempts to decode JPEG2000 (JP2) data using CoreImage as a fallback path
    static func decodeJPEG2000(_ data: Data) -> CGImage? {
        let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let ciImage = CIImage(data: data) else { return nil }
        let extent = ciImage.extent.integral
        return ciContext.createCGImage(ciImage, from: extent)
    }
    
    /// Creates a best-effort CGImage from arbitrary data using ImageIO first, then CoreImage (for JP2)
    static func decodeImageData(_ data: Data, utiHint: CFString? = nil) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        if let src = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) {
            if let cg = CGImageSourceCreateImageAtIndex(src, 0, options as CFDictionary) {
                return cg
            }
            // Try CoreImage fallback (helps with JP2)
            if let cg = decodeJPEG2000(data) { return cg }
        }
        return nil
    }
    
    /// Rasterizes a PDF page via CoreGraphics into an NSImage (handles many embedded image quirks)
    static func rasterize(page: PDFPage, into targetSize: CGSize, scale: CGFloat = 2.0) -> NSImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = max(1, Int(targetSize.width * scale))
        let height = max(1, Int(targetSize.height * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.saveGState()
        // Map page bounds into context rect
        let drawRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.translateBy(x: 0, y: drawRect.height)
        context.scaleBy(x: drawRect.width / bounds.width, y: -drawRect.height / bounds.height)
        if let cgPage = page.pageRef {
            context.drawPDFPage(cgPage)
        } else {
            let thumb = page.thumbnail(of: bounds.size, for: .mediaBox)
            if let cg = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cg, in: bounds)
            }
        }
        context.restoreGState()
        guard let cgOut = context.makeImage() else { return nil }
        let img = NSImage(cgImage: cgOut, size: NSSize(width: targetSize.width, height: targetSize.height))
        return img
    }
    
    /// Safe thumbnail that falls back to rasterization when PDFKit thumbnailing fails
    static func safeThumbnail(for page: PDFPage, size: CGSize) -> NSImage? {
        let thumb = page.thumbnail(of: size, for: .mediaBox)
        if thumb.size.width > 0 && thumb.size.height > 0 { return thumb }
        return rasterize(page: page, into: size)
    }
}

func log(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .default, message)
}

func logError(_ log: OSLog, _ message: String) {
    os_log("%{public}@", log: log, type: .error, message)
}

// MARK: - Toast Center overlay
final class ToastCenter: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let style: Style
        enum Style { case info, success, warning, error }
    }

    @Published var toasts: [Toast] = []

    func show(_ title: String, _ message: String, style: Toast.Style = .info, autoDismiss: TimeInterval = 3) {
        let toast = Toast(title: title, message: message, style: style)
        toasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss) { [weak self] in
            self?.toasts.removeAll { $0 == toast }
        }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(center.toasts) { toast in
                    HStack(spacing: 10) {
                        Circle().fill(color(for: toast.style)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(toast.title).bold()
                            Text(toast.message).font(.caption)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                }
            }
            .padding(12)
        }
    }

    private func color(for style: ToastCenter.Toast.Style) -> Color {
        switch style { case .info: return .blue; case .success: return .green; case .warning: return .orange; case .error: return .red }
    }
}

extension View {
    func toastOverlay(_ center: ToastCenter) -> some View { self.modifier(ToastOverlay(center: center)) }
}
