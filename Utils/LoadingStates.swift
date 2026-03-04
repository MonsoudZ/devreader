import SwiftUI
import Foundation
import Combine
import os.log

// MARK: - Loading State Manager
@MainActor
class LoadingStateManager: ObservableObject {
    static let shared = LoadingStateManager()

    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var loadingProgress: Double = 0.0
    @Published var loadingType: LoadingType = .general

    private static let logger = AppLog.loading
    private static let safetyTimeoutSeconds: TimeInterval = 30

    private var loadingTasks: Set<String> = []
    private var timeoutTasks: [String: Task<Void, Never>] = [:]
    
    enum LoadingType {
        case general
        case pdf
        case search
        case file
        case monaco
        case web
        case sketch
        case export
        case `import`
        case backup
        case restore
    }
    
    private init() {}
    
    // MARK: - Loading Control
    func startLoading(_ type: LoadingType, message: String, progress: Double = 0.0) {
        let taskId = "\(type)"
        loadingTasks.insert(taskId)

        isLoading = true
        loadingType = type
        loadingMessage = message
        loadingProgress = progress

        os_log("Started loading: %{public}@ - %{public}@", log: Self.logger, type: .info, String(describing: type), message)

        // Cancel any existing timeout for this task before scheduling a new one
        timeoutTasks[taskId]?.cancel()
        timeoutTasks[taskId] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.safetyTimeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            os_log("Safety timeout fired for: %{public}@", log: Self.logger, type: .error, taskId)
            self?.stopLoading(type)
        }
    }
    
    func updateProgress(_ progress: Double, message: String? = nil) {
        loadingProgress = progress
        if let message = message {
            loadingMessage = message
        }
    }
    
    func stopLoading(_ type: LoadingType) {
        let taskId = "\(type)"
        loadingTasks.remove(taskId)

        timeoutTasks[taskId]?.cancel()
        timeoutTasks[taskId] = nil

        if loadingTasks.isEmpty {
            isLoading = false
            loadingMessage = ""
            loadingProgress = 0.0
        }

        os_log("Stopped loading: %{public}@", log: Self.logger, type: .info, String(describing: type))
    }
    
    func stopAllLoading() {
        loadingTasks.removeAll()
        for task in timeoutTasks.values { task.cancel() }
        timeoutTasks.removeAll()
        isLoading = false
        loadingMessage = ""
        loadingProgress = 0.0
    }
}

// MARK: - Loading Overlay View
/// Non-blocking loading indicator shown as a small floating pill at the top
/// of the window. Does NOT prevent user interaction with the rest of the UI.
struct LoadingOverlay: View {
    @ObservedObject var loadingManager = LoadingStateManager.shared

    var body: some View {
        if loadingManager.isLoading {
            VStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text(loadingManager.loadingMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if loadingManager.loadingProgress > 0 {
                        ProgressView(value: loadingManager.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 80)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.top, 8)

                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: loadingManager.isLoading)
        }
    }
}

// MARK: - Loading Button
struct LoadingButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    @ObservedObject var loadingManager = LoadingStateManager.shared
    let loadingType: LoadingStateManager.LoadingType
    let loadingMessage: String
    
    init(
        loadingType: LoadingStateManager.LoadingType,
        loadingMessage: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.loadingType = loadingType
        self.loadingMessage = loadingMessage
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button(action: {
            loadingManager.startLoading(loadingType, message: loadingMessage)
            action()
        }) {
            HStack {
                if loadingManager.isLoading && loadingManager.loadingType == loadingType {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                } else {
                    label
                }
            }
        }
        .disabled(loadingManager.isLoading)
    }
}

// MARK: - Loading States for Specific Operations
extension LoadingStateManager {
    
    // PDF Operations
    func startPDFLoading(_ message: String = "Loading PDF...") {
        startLoading(.pdf, message: message)
    }
    
    func updatePDFProgress(_ progress: Double, message: String? = nil) {
        updateProgress(progress, message: message)
    }
    
    func stopPDFLoading() {
        stopLoading(.pdf)
    }
    
    // Search Operations
    func startSearch(_ message: String = "Searching...") {
        startLoading(.search, message: message)
    }
    
    func stopSearch() {
        stopLoading(.search)
    }
    
    // File Operations
    func startFileOperation(_ message: String = "Processing file...") {
        startLoading(.file, message: message)
    }
    
    func stopFileOperation() {
        stopLoading(.file)
    }
    
    // Monaco Editor
    func startMonacoLoading(_ message: String = "Initializing editor...") {
        startLoading(.monaco, message: message)
    }
    
    func stopMonacoLoading() {
        stopLoading(.monaco)
    }
    
    // Web Operations
    func startWebLoading(_ message: String = "Loading webpage...") {
        startLoading(.web, message: message)
    }
    
    func stopWebLoading() {
        stopLoading(.web)
    }
    
    // Export Operations
    func startExport(_ message: String = "Exporting...") {
        startLoading(.export, message: message)
    }
    
    func updateExportProgress(_ progress: Double, message: String? = nil) {
        updateProgress(progress, message: message)
    }
    
    func stopExport() {
        stopLoading(.export)
    }
    
    // Import Operations
    func startImport(_ message: String = "Importing...") {
        startLoading(.import, message: message)
    }
    
    func updateImportProgress(_ progress: Double, message: String? = nil) {
        updateProgress(progress, message: message)
    }
    
    func stopImport() {
        stopLoading(.import)
    }
    
    // Backup Operations
    func startBackup(_ message: String = "Creating backup...") {
        startLoading(.backup, message: message)
    }
    
    func stopBackup() {
        stopLoading(.backup)
    }
    
    // Restore Operations
    func startRestore(_ message: String = "Restoring from backup...") {
        startLoading(.restore, message: message)
    }
    
    func stopRestore() {
        stopLoading(.restore)
    }
}
