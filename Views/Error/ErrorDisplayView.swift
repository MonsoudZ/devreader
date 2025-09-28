import SwiftUI
import Foundation

/// Comprehensive error display system for user-facing errors
struct ErrorDisplayView: View {
    let error: UserFriendlyError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    let onRecover: (() -> Void)?
    
    @State private var showingDetails = false
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Error icon and title
            HStack {
                errorIcon
                    .foregroundColor(errorColor)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            // Recovery actions
            if !error.recoveryActions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(error.recoveryActions.enumerated()), id: \.offset) { index, action in
                        Button(action: {
                            if action.title.contains("Retry") {
                                performRetry()
                            } else if action.title.contains("Recover") {
                                performRecover()
                            } else {
                                action.action()
                            }
                        }) {
                            HStack {
                                if action.title.contains("Retry") && isRetrying {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    actionIcon(for: action)
                                }
                                
                                Text(action.title)
                                    .font(.body)
                                    .foregroundColor(actionColor(for: action))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(backgroundColor(for: action))
                            .cornerRadius(8)
                        }
                        .disabled(isRetrying)
                    }
                }
            }
            
            // Technical details (expandable)
            if !(error.technicalDetails?.isEmpty ?? true) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingDetails.toggle()
                        }
                    }) {
                        HStack {
                            Text("Technical Details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showingDetails {
                        Text(error.technicalDetails ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
            
            // Dismiss button
            HStack {
                Spacer()
                
                Button("Dismiss") {
                    onDismiss()
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
    
    // MARK: - View Components
    
    private var errorIcon: some View {
        Group {
            switch error.severity {
            case .info:
                Image(systemName: "info.circle.fill")
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
            case .error:
                Image(systemName: "xmark.circle.fill")
            case .critical:
                Image(systemName: "exclamationmark.octagon.fill")
            }
        }
    }
    
    private var errorColor: Color {
        switch error.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .red
        }
    }
    
    private func actionIcon(for action: RecoveryAction) -> some View {
        Group {
            if action.title.contains("Retry") {
                Image(systemName: "arrow.clockwise")
            } else if action.title.contains("Recover") {
                Image(systemName: "arrow.triangle.2.circlepath")
            } else if action.title.contains("Open") {
                Image(systemName: "folder")
            } else if action.title.contains("Settings") {
                Image(systemName: "gearshape")
            } else {
                Image(systemName: "arrow.right")
            }
        }
    }
    
    private func actionColor(for action: RecoveryAction) -> Color {
        if action.style == .primary {
            return .white
        } else {
            return .primary
        }
    }
    
    private func backgroundColor(for action: RecoveryAction) -> Color {
        if action.style == .primary {
            return errorColor
        } else {
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    // MARK: - Actions
    
    private func performRetry() {
        guard let onRetry = onRetry else { return }
        
        isRetrying = true
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            onRetry()
            isRetrying = false
        }
    }
    
    private func performRecover() {
        guard let onRecover = onRecover else { return }
        onRecover()
    }
}

// MARK: - Error Overlay Modifier

struct ErrorOverlayModifier: ViewModifier {
    @ObservedObject var errorManager: ErrorMessageManager
    @State private var showingError = false
    @State private var currentError: UserFriendlyError?
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showingError, let error = currentError {
                        ZStack {
                            // Background overlay
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    dismissError()
                                }
                            
                            // Error display
                            ErrorDisplayView(
                                error: error,
                                onDismiss: {
                                    dismissError()
                                },
                                onRetry: error.recoveryActions.contains { $0.title.contains("Retry") } ? {
                                    // Retry action - implementation needed
                                } : nil,
                                onRecover: error.recoveryActions.contains { $0.title.contains("Recover") } ? {
                                    // Recover action - implementation needed
                                } : nil
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                }
            )
            .onReceive(errorManager.$currentError) { error in
                if let error = error {
                    currentError = error
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingError = true
                    }
                } else {
                    dismissError()
                }
            }
    }
    
    private func dismissError() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingError = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentError = nil
            errorManager.dismissError()
        }
    }
}

extension View {
    func errorOverlay(_ errorManager: ErrorMessageManager) -> some View {
        self.modifier(ErrorOverlayModifier(errorManager: errorManager))
    }
}

// MARK: - Error Toast View

struct ErrorToastView: View {
    let error: UserFriendlyError
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Error icon
            Group {
                switch error.severity {
                case .info:
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                case .warning:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                case .error:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                case .critical:
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.title2)
            
            // Error content
            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Error Toast Overlay

struct ErrorToastOverlay: View {
    @ObservedObject var errorManager: ErrorMessageManager
    
    var body: some View {
        VStack {
            Spacer()
            
            if let error = errorManager.currentError {
                ErrorToastView(
                    error: error,
                    onDismiss: {
                        errorManager.dismissError()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

extension View {
    func errorToastOverlay(_ errorManager: ErrorMessageManager) -> some View {
        self.overlay(
            ErrorToastOverlay(errorManager: errorManager)
        )
    }
}
