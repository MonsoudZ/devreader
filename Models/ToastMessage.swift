import SwiftUI

nonisolated struct ToastMessage: Identifiable, Sendable {
    let id = UUID()
    let message: String
    let type: ToastType

    nonisolated enum ToastType: Sendable {
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
