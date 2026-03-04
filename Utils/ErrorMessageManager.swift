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
    
    private let logger = AppLog.app
    
    init() {}
    
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
    let action: @MainActor () -> Void
    
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



