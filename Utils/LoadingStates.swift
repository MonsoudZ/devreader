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
    
    private var loadingTasks: Set<String> = []
    
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
        
        os_log("Started loading: %{public}@ - %{public}@", log: OSLog.default, type: .info, String(describing: type), message)
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
        
        if loadingTasks.isEmpty {
            isLoading = false
            loadingMessage = ""
            loadingProgress = 0.0
        }
        
        os_log("Stopped loading: %{public}@", log: OSLog.default, type: .info, String(describing: type))
    }
    
    func stopAllLoading() {
        loadingTasks.removeAll()
        isLoading = false
        loadingMessage = ""
        loadingProgress = 0.0
    }
}

// MARK: - Loading Overlay View
struct LoadingOverlay: View {
    @ObservedObject var loadingManager = LoadingStateManager.shared
    
    var body: some View {
        if loadingManager.isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text(loadingManager.loadingMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if loadingManager.loadingProgress > 0 {
                        ProgressView(value: loadingManager.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
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
