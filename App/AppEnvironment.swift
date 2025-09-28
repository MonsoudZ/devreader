import SwiftUI
import Combine

/// Centralized app environment for consistent state across windows
@MainActor
class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    
    // Core controllers
    @Published var pdfController: PDFController
    @Published var notesStore: NotesStore
    @Published var libraryStore: LibraryStore
    @Published var sketchStore: SketchStore
    @Published var codeStore: CodeStore
    @Published var webStore: WebStore
    
    // Services
    @Published var errorMessageManager: ErrorMessageManager
    @Published var enhancedToastCenter: EnhancedToastCenter
    
    // UI State
    @Published var isShowingHelp = false
    @Published var isShowingSettings = false
    @Published var isShowingOnboarding = false
    
    private init() {
        // Initialize core controllers
        self.pdfController = PDFController()
        self.notesStore = NotesStore()
        self.libraryStore = LibraryStore()
        self.sketchStore = SketchStore()
        self.codeStore = CodeStore()
        self.webStore = WebStore()
        
        // Initialize services
        self.errorMessageManager = ErrorMessageManager.shared
        self.enhancedToastCenter = EnhancedToastCenter()
        
        // Set up cross-controller communication
        setupControllerCommunication()
        
        // Check for first launch
        checkFirstLaunch()
    }
    
    private func setupControllerCommunication() {
        // PDF controller changes should update notes store
        // Note: PDFController doesn't have @Published currentPDFURL, so we'll use notifications instead
        
        // Library store changes should update PDF controller
        libraryStore.$items
            .sink { [weak self] items in
                // Update recent documents in PDF controller
                self?.pdfController.updateRecentDocuments(from: items)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            isShowingOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    // MARK: - Window Management
    
    func openNewWindow() {
        // Create new window with same environment
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentView = NSHostingView(rootView: ContentView().environmentObject(self))
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    func openSettings() {
        isShowingSettings = true
    }
    
    func openHelp() {
        isShowingHelp = true
    }
    
    // MARK: - Data Management
    
    func clearAllData() {
        // Clear all data from stores
        notesStore.items.removeAll()
        libraryStore.items.removeAll()
        sketchStore.clearAllData()
        codeStore.clearAllData()
        webStore.clearAllData()
        pdfController.document = nil
    }
    
    func exportAllData() -> URL? {
        // Create export package with all data
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("DevReaderExport.zip")
        // Implementation would create a zip with all data
        return exportURL
    }
    
    func importData(from url: URL) {
        // Implementation would import data from file
        // This would restore notes, library, sketches, etc.
    }
}

// MARK: - Extensions for PDFController

extension PDFController {
    func updateRecentDocuments(from items: [LibraryItem]) {
        // Update recent documents based on library items
        _ = items
            .sorted { $0.lastOpened ?? $0.addedDate > $1.lastOpened ?? $1.addedDate }
            .prefix(10)
            .map { $0.url }
        
        // Note: PDFController.recentDocuments is not directly settable
        // This would need to be implemented in PDFController
    }
}
