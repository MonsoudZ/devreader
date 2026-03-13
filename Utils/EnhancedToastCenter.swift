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

        static func == (lhs: EnhancedToast, rhs: EnhancedToast) -> Bool {
            lhs.id == rhs.id
        }

        enum Style: CaseIterable {
            case info, success, warning, error, critical
            
            var color: Color {
                switch self {
                case .info: return DS.Colors.info
                case .success: return DS.Colors.success
                case .warning: return DS.Colors.warning
                case .error: return DS.Colors.error
                case .critical: return DS.Colors.critical
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
    
    // MARK: - Dismissal

    /// Dismisses a toast, correctly resetting `isShowingCriticalError` when needed.
    func dismissToast(_ toast: EnhancedToast) {
        removeToast(toast)
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
    
}

// MARK: - Enhanced Toast Display

struct EnhancedToastOverlay: ViewModifier {
    @ObservedObject var center: EnhancedToastCenter
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            
            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                ForEach(center.toasts) { toast in
                    EnhancedToastView(toast: toast) {
                        center.dismissToast(toast)
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
    }
}

struct EnhancedToastView: View {
    let toast: EnhancedToastCenter.EnhancedToast
    let onDismiss: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            VStack {
                Image(systemName: toast.style.icon)
                    .foregroundStyle(toast.style.color)
                    .font(.title2)

                Image(systemName: toast.category.icon)
                    .foregroundStyle(DS.Colors.secondary)
                    .font(DS.Typography.caption)
            }

            // Content
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(toast.title)
                    .font(DS.Typography.heading)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.primary)

                Text(toast.message)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.secondary)
                    .multilineTextAlignment(.leading)

                // Category and timestamp
                HStack {
                    Text(toast.category.rawValue)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiary)

                    Spacer()

                    Text(toast.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiary)
                }
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
            .buttonStyle(DSToolbarButtonStyle())
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .shadow(color: DS.Shadow.glow(toast.style.color).color, radius: DS.Shadow.glow(toast.style.color).radius, x: DS.Shadow.glow(toast.style.color).x, y: DS.Shadow.glow(toast.style.color).y)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(toast.style.color.opacity(0.5), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(DS.Animation.spring, value: isVisible)
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

