import SwiftUI
import Foundation
import os.log
import Combine

/// Enhanced error message management system for DevReader
/// Provides user-friendly, actionable error messages with recovery options
@MainActor
class ErrorMessageManager: ObservableObject {
    static let shared = ErrorMessageManager()
    
    @Published var currentError: UserFriendlyError?
    @Published var isShowingError = false
    
    private let logger = OSLog(subsystem: "dev.local.chace.DevReader", category: "ErrorMessageManager")
    
    private init() {}
    
    // MARK: - Error Display
    
    /// Shows a user-friendly error with recovery options
    func showError(_ error: UserFriendlyError) {
        currentError = error
        isShowingError = true
        
        os_log("Showing user error: %{public}@", log: logger, type: .error, error.title)
    }
    
    /// Dismisses the current error
    func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    // MARK: - Error Creation Helpers
    
    /// Creates a PDF loading error with recovery options
    static func pdfLoadingError(for url: URL, originalError: Error) -> UserFriendlyError {
        let fileName = url.lastPathComponent
        
        return UserFriendlyError(
            title: "Unable to Open PDF",
            message: "DevReader couldn't open \"\(fileName)\". This might be due to file corruption or an unsupported format.",
            severity: .error,
            category: .fileAccess,
            recoveryActions: [
                RecoveryAction(
                    title: "Try Again",
                    style: .primary,
                    action: { ErrorMessageManager.shared.dismissError() }
                ),
                RecoveryAction(
                    title: "Choose Different File",
                    style: .secondary,
                    action: { 
                        NotificationCenter.default.post(name: .openPDF, object: nil)
                        ErrorMessageManager.shared.dismissError()
                    }
                ),
                RecoveryAction(
                    title: "Get Help",
                    style: .tertiary,
                    action: { 
                        NotificationCenter.default.post(name: .showHelp, object: nil)
                        ErrorMessageManager.shared.dismissError()
                    }
                )
            ],
            technicalDetails: "File: \(url.path)\nError: \(originalError.localizedDescription)"
        )
    }
    
    /// Creates a file access error
    static func fileAccessError(for url: URL, reason: ErrorMessageManager.FileAccessReason) -> UserFriendlyError {
        let fileName = url.lastPathComponent
        
        let (title, message): (String, String) = switch reason {
        case .notFound:
            ("File Not Found", "The file \"\(fileName)\" could not be found. It may have been moved, renamed, or deleted.")
        case .permissionDenied:
            ("Access Denied", "DevReader doesn't have permission to access \"\(fileName)\". Please check the file permissions.")
        case .corrupted:
            ("File Corrupted", "The file \"\(fileName)\" appears to be corrupted and cannot be opened.")
        case .unsupportedFormat:
            ("Unsupported Format", "The file \"\(fileName)\" is not a valid PDF or uses an unsupported format.")
        case .networkError:
            ("Network Error", "Unable to access \"\(fileName)\" due to a network connection issue.")
        }
        
        return UserFriendlyError(
            title: title,
            message: message,
            severity: .error,
            category: .fileAccess,
            recoveryActions: [
                RecoveryAction(
                    title: "Choose Different File",
                    style: .primary,
                    action: { 
                        NotificationCenter.default.post(name: .openPDF, object: nil)
                        ErrorMessageManager.shared.dismissError()
                    }
                ),
                RecoveryAction(
                    title: "Get Help",
                    style: .secondary,
                    action: { 
                        NotificationCenter.default.post(name: .showHelp, object: nil)
                        ErrorMessageManager.shared.dismissError()
                    }
                )
            ]
        )
    }
    
    /// Creates a memory error
    static func memoryError(operation: String) -> UserFriendlyError {
        return UserFriendlyError(
            title: "Insufficient Memory",
            message: "DevReader doesn't have enough memory to \(operation). Try closing other applications or opening a smaller PDF.",
            severity: .warning,
            category: .performance,
            recoveryActions: [
                RecoveryAction(
                    title: "Close Other Apps",
                    style: .primary,
                    action: { 
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ActivityMonitor") {
                            NSWorkspace.shared.open(url)
                        }
                        ErrorMessageManager.shared.dismissError()
                    }
                ),
                RecoveryAction(
                    title: "Try Smaller PDF",
                    style: .secondary,
                    action: { 
                        NotificationCenter.default.post(name: .openPDF, object: nil)
                        ErrorMessageManager.shared.dismissError()
                    }
                ),
                RecoveryAction(
                    title: "Restart DevReader",
                    style: .tertiary,
                    action: { 
                        NSApplication.shared.terminate(nil)
                    }
                )
            ]
        )
    }
    
    /// Creates a network error
    static func networkError(operation: String) -> UserFriendlyError {
        return UserFriendlyError(
            title: "Network Connection Failed",
            message: "DevReader couldn't \(operation) due to a network issue. Please check your internet connection.",
            severity: .error,
            category: .network,
            recoveryActions: [
                RecoveryAction(
                    title: "Try Again",
                    style: .primary,
                    action: { ErrorMessageManager.shared.dismissError() }
                ),
                RecoveryAction(
                    title: "Check Connection",
                    style: .secondary,
                    action: { 
                        NSWorkspace.shared.open(URL(string: "https://www.apple.com/support/")!)
                        ErrorMessageManager.shared.dismissError()
                    }
                )
            ]
        )
    }
    
    /// Creates a permission error
    static func permissionError(for resource: String) -> UserFriendlyError {
        return UserFriendlyError(
            title: "Permission Required",
            message: "DevReader needs permission to access \(resource). Please grant permission in System Preferences.",
            severity: .warning,
            category: .permission,
            recoveryActions: [
                RecoveryAction(
                    title: "Open System Preferences",
                    style: .primary,
                    action: { 
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                        ErrorMessageManager.shared.dismissError()
                    }
                ),
                RecoveryAction(
                    title: "Try Again",
                    style: .secondary,
                    action: { ErrorMessageManager.shared.dismissError() }
                )
            ]
        )
    }
}

// MARK: - User-Friendly Error Model

struct UserFriendlyError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ErrorSeverity
    let category: ErrorCategory
    let recoveryActions: [RecoveryAction]
    let technicalDetails: String?
    let timestamp = Date()
    
    init(
        title: String,
        message: String,
        severity: ErrorSeverity,
        category: ErrorCategory,
        recoveryActions: [RecoveryAction] = [],
        technicalDetails: String? = nil
    ) {
        self.title = title
        self.message = message
        self.severity = severity
        self.category = category
        self.recoveryActions = recoveryActions
        self.technicalDetails = technicalDetails
    }
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error Category

enum ErrorCategory: String, CaseIterable {
    case fileAccess = "File Access"
    case network = "Network"
    case permission = "Permission"
    case performance = "Performance"
    case data = "Data"
    case system = "System"
    
    var icon: String {
        switch self {
        case .fileAccess: return "doc.text"
        case .network: return "network"
        case .permission: return "lock"
        case .performance: return "speedometer"
        case .data: return "database"
        case .system: return "gear"
        }
    }
}

// MARK: - Recovery Action

struct RecoveryAction: Identifiable {
    let id = UUID()
    let title: String
    let style: RecoveryActionStyle
    let action: () -> Void
    
    enum RecoveryActionStyle {
        case primary
        case secondary
        case tertiary
        case destructive
        
        var isPrimary: Bool {
            switch self {
            case .primary: return true
            case .secondary, .tertiary, .destructive: return false
            }
        }
        
        var color: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .gray
            case .tertiary: return .gray
            case .destructive: return .red
            }
        }
    }
}

// MARK: - File Access Reasons

extension ErrorMessageManager {
    enum FileAccessReason {
        case notFound
        case permissionDenied
        case corrupted
        case unsupportedFormat
        case networkError
    }
}

// MARK: - Extensions (errorOverlay moved to ErrorDisplayView.swift)

// MARK: - Notification Names

extension Notification.Name {
    static let openPDF = Notification.Name("openPDF")
    static let showHelp = Notification.Name("showHelp")
    static let addNote = Notification.Name("addNote")
    static let showToast = Notification.Name("showToast")
    static let importPDFs = Notification.Name("importPDFs")
    static let toggleSearch = Notification.Name("toggleSearch")
}

// MARK: - Toast Message Model

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    
    enum ToastType {
        case success
        case error
        case warning
        case info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle"
            case .error: return "xmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .info: return "info.circle"
            }
        }
    }
}