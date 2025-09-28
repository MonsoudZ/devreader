import SwiftUI
import Foundation
import Combine

/// Enhanced toast notification system with improved error messages
@MainActor
final class EnhancedToastCenter: ObservableObject {
    struct EnhancedToast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let style: Style
        let category: ToastCategory
        let duration: TimeInterval
        let timestamp = Date()
        
        enum Style: CaseIterable {
            case info, success, warning, error, critical
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .success: return .green
                case .warning: return .orange
                case .error: return .red
                case .critical: return .purple
                }
            }
            
            var icon: String {
                switch self {
                case .info: return "info.circle"
                case .success: return "checkmark.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                case .critical: return "exclamationmark.octagon"
                }
            }
        }
        
        enum ToastCategory: String, CaseIterable {
            case fileOperation = "File Operation"
            case network = "Network"
            case performance = "Performance"
            case userAction = "User Action"
            case system = "System"
            
            var icon: String {
                switch self {
                case .fileOperation: return "doc.text"
                case .network: return "network"
                case .performance: return "speedometer"
                case .userAction: return "person"
                case .system: return "gear"
                }
            }
        }
    }
    
    @Published var toasts: [EnhancedToast] = []
    @Published var isShowingCriticalError = false
    
    private let maxToasts = 5
    private let defaultDuration: TimeInterval = 4.0
    
    // MARK: - Toast Creation Methods
    
    /// Shows a success toast
    func showSuccess(_ title: String, _ message: String, category: EnhancedToast.ToastCategory = .userAction, duration: TimeInterval? = nil) {
        let toast = EnhancedToast(
            title: title,
            message: message,
            style: .success,
            category: category,
            duration: duration ?? defaultDuration
        )
        addToast(toast)
    }
    
    /// Shows an info toast
    func showInfo(_ title: String, _ message: String, category: EnhancedToast.ToastCategory = .userAction, duration: TimeInterval? = nil) {
        let toast = EnhancedToast(
            title: title,
            message: message,
            style: .info,
            category: category,
            duration: duration ?? defaultDuration
        )
        addToast(toast)
    }
    
    /// Shows a warning toast
    func showWarning(_ title: String, _ message: String, category: EnhancedToast.ToastCategory = .system, duration: TimeInterval? = nil) {
        let toast = EnhancedToast(
            title: title,
            message: message,
            style: .warning,
            category: category,
            duration: duration ?? defaultDuration
        )
        addToast(toast)
    }
    
    /// Shows an error toast
    func showError(_ title: String, _ message: String, category: EnhancedToast.ToastCategory = .system, duration: TimeInterval? = nil) {
        let toast = EnhancedToast(
            title: title,
            message: message,
            style: .error,
            category: category,
            duration: duration ?? defaultDuration
        )
        addToast(toast)
    }
    
    /// Shows a critical error toast
    func showCriticalError(_ title: String, _ message: String, category: EnhancedToast.ToastCategory = .system, duration: TimeInterval? = nil) {
        let toast = EnhancedToast(
            title: title,
            message: message,
            style: .critical,
            category: category,
            duration: duration ?? defaultDuration
        )
        addToast(toast)
        isShowingCriticalError = true
    }
    
    // MARK: - Specialized Error Messages
    
    /// Shows a PDF loading error with helpful context
    func showPDFLoadingError(for url: URL, error: Error) {
        let fileName = url.lastPathComponent
        let errorMessage = getPDFErrorMessage(for: error)
        
        showError(
            "Couldn't Open PDF",
            "Failed to open \"\(fileName)\". \(errorMessage)",
            category: .fileOperation,
            duration: 6.0
        )
    }
    
    /// Shows a file access error
    func showFileAccessError(for url: URL, reason: FileAccessReason) {
        let fileName = url.lastPathComponent
        let (title, message) = getFileAccessErrorMessage(fileName: fileName, reason: reason)
        
        showError(title, message, category: .fileOperation, duration: 5.0)
    }
    
    /// Shows a memory warning
    func showMemoryWarning(operation: String) {
        showWarning(
            "Low Memory",
            "DevReader is running low on memory while \(operation). Consider closing other applications.",
            category: .performance,
            duration: 8.0
        )
    }
    
    /// Shows a network error
    func showNetworkError(operation: String) {
        showError(
            "Network Error",
            "Unable to \(operation) due to a network connection issue. Please check your internet connection.",
            category: .network,
            duration: 6.0
        )
    }
    
    /// Shows a permission error
    func showPermissionError(for resource: String) {
        showWarning(
            "Permission Required",
            "DevReader needs permission to access \(resource). Please grant permission in System Preferences.",
            category: .system,
            duration: 8.0
        )
    }
    
    /// Shows a performance warning
    func showPerformanceWarning(operation: String, suggestion: String) {
        showWarning(
            "Performance Notice",
            "\(operation) is taking longer than expected. \(suggestion)",
            category: .performance,
            duration: 5.0
        )
    }
    
    // MARK: - Private Methods
    
    private func addToast(_ toast: EnhancedToast) {
        // Remove oldest toast if we're at the limit
        if toasts.count >= maxToasts {
            toasts.removeFirst()
        }
        
        toasts.append(toast)
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) { [weak self] in
            self?.removeToast(toast)
        }
    }
    
    private func removeToast(_ toast: EnhancedToast) {
        toasts.removeAll { $0.id == toast.id }
        
        // Reset critical error flag if no critical errors remain
        if !toasts.contains(where: { $0.style == .critical }) {
            isShowingCriticalError = false
        }
    }
    
    private func getPDFErrorMessage(for error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("corrupted") || errorDescription.contains("invalid") {
            return "The file appears to be corrupted or invalid."
        } else if errorDescription.contains("permission") || errorDescription.contains("access") {
            return "You don't have permission to access this file."
        } else if errorDescription.contains("format") || errorDescription.contains("unsupported") {
            return "The file format is not supported or is not a valid PDF."
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return "There was a network connection issue."
        } else if errorDescription.contains("memory") || errorDescription.contains("resource") {
            return "Insufficient memory or system resources."
        } else {
            return "An unexpected error occurred."
        }
    }
    
    private func getFileAccessErrorMessage(fileName: String, reason: FileAccessReason) -> (String, String) {
        switch reason {
        case .notFound:
            return ("File Not Found", "The file \"\(fileName)\" could not be found. It may have been moved or deleted.")
        case .permissionDenied:
            return ("Access Denied", "You don't have permission to access \"\(fileName)\". Please check the file permissions.")
        case .corrupted:
            return ("File Corrupted", "The file \"\(fileName)\" appears to be corrupted and cannot be opened.")
        case .unsupportedFormat:
            return ("Unsupported Format", "The file \"\(fileName)\" is not a valid PDF or uses an unsupported format.")
        case .networkError:
            return ("Network Error", "Unable to access \"\(fileName)\" due to a network connection issue.")
        }
    }
}

// MARK: - Enhanced Toast Display

struct EnhancedToastOverlay: ViewModifier {
    @ObservedObject var center: EnhancedToastCenter
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            
            VStack(alignment: .trailing, spacing: 12) {
                ForEach(center.toasts) { toast in
                    EnhancedToastView(toast: toast) {
                        center.toasts.removeAll { $0.id == toast.id }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct EnhancedToastView: View {
    let toast: EnhancedToastCenter.EnhancedToast
    let onDismiss: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            VStack {
                Image(systemName: toast.style.icon)
                    .foregroundStyle(toast.style.color)
                    .font(.title2)
                
                Image(systemName: toast.category.icon)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(toast.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                
                // Category and timestamp
                HStack {
                    Text(toast.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    Text(toast.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: toast.style.color.opacity(0.3), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.style.color.opacity(0.5), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// MARK: - View Extension

extension View {
    func enhancedToastOverlay(_ center: EnhancedToastCenter) -> some View {
        self.modifier(EnhancedToastOverlay(center: center))
    }
}

// MARK: - File Access Reasons

extension EnhancedToastCenter {
    enum FileAccessReason {
        case notFound
        case permissionDenied
        case corrupted
        case unsupportedFormat
        case networkError
    }
}
