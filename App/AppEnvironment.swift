import Foundation
import SwiftUI
import Combine

/// Central app-wide state container. Holds shared controllers, stores, and UI services.
/// Injected via `@EnvironmentObject` from `DevReaderApp`.
@MainActor
final class AppEnvironment: ObservableObject {

    // MARK: - Core Controllers & Stores
    private(set) var tabManager: TabManager
    private(set) var secondaryPDFController: PDFController
    private(set) var libraryStore: LibraryStore
    private(set) var notesStore: NotesStore
    private(set) var sketchStore: SketchStore
    private(set) var signatureStore: SignatureStore
    private(set) var ttsService: TextToSpeechService

    /// Backward-compatible accessor: returns the active tab's PDFController.
    var pdfController: PDFController { tabManager.activeController }

    // MARK: - UI Services
    private(set) var enhancedToastCenter: EnhancedToastCenter
    private(set) var errorMessageManager: ErrorMessageManager
    private(set) var loadingStateManager: LoadingStateManager
    private(set) var performanceMonitor: PerformanceMonitor

    // MARK: - Sheet Toggles
    @Published var isShowingOnboarding = false
    @Published var isShowingSettings = false
    @Published var isShowingHelp = false
    @Published var isShowingAbout = false
    @Published var isShowingProperties = false
    @Published var isShowingFormFields = false
    @Published var isShowingAnnotations = false
    @Published var isShowingComparison = false
    @Published var isShowingSignaturePad = false

    // MARK: - Init
    init(
        loadingStateManager: LoadingStateManager = .shared,
        performanceMonitor: PerformanceMonitor = .shared,
        errorMessageManager: ErrorMessageManager = ErrorMessageManager()
    ) {
        self.loadingStateManager = loadingStateManager
        self.performanceMonitor = performanceMonitor
        self.errorMessageManager = errorMessageManager

        let tabMgr = TabManager(loadingStateManager: loadingStateManager, performanceMonitor: performanceMonitor)
        let library = LibraryStore(loadingStateManager: loadingStateManager)
        let notes = NotesStore()

        self.tabManager = tabMgr
        self.secondaryPDFController = PDFController(loadingStateManager: loadingStateManager, performanceMonitor: performanceMonitor)
        self.libraryStore = library
        self.notesStore = notes
        self.sketchStore = SketchStore()
        self.signatureStore = SignatureStore()
        self.ttsService = TextToSpeechService()
        self.enhancedToastCenter = EnhancedToastCenter()

        // Wire the initial tab's PDF changes to notes store
        let initialController = tabMgr.activeController
        initialController.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        // Re-wire onPDFChanged whenever the active tab changes
        tabChangeCancellable = tabMgr.activeTabChanged
            .sink { [weak notes] controller in
                controller.onPDFChanged = { [weak notes] url in
                    notes?.setCurrentPDF(url)
                }
                // Sync notes to the newly active tab's PDF
                notes?.setCurrentPDF(controller.currentPDFURL)
            }

        // Forward tabManager changes so SwiftUI re-renders on tab switch
        wireTabManagerChanges(tabMgr)

        // Restore last-opened PDF after init completes and wiring is in place
        restoreTask = Task { [weak tabMgr, weak notes] in
            tabMgr?.activeController.restoreLastOpenedPDF()
            // Manually sync notes in case the PDF loaded before onPDFChanged could fire
            if let url = tabMgr?.activeController.currentPDFURL {
                notes?.setCurrentPDF(url)
            }
        }
    }

    private var restoreTask: Task<Void, Never>?
    private var tabChangeCancellable: AnyCancellable?
    private var tabManagerSink: AnyCancellable?

    /// Forward tabManager's objectWillChange so SwiftUI re-renders
    /// ContentView when the active tab switches.
    private func wireTabManagerChanges(_ tabMgr: TabManager) {
        tabManagerSink = tabMgr.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - Auto-Backup
    private var autoBackupCancellable: AnyCancellable?

    func setupAutoBackupTimer() {
        autoBackupCancellable?.cancel()
        let enabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        guard enabled else { return }
        let intervalHours = UserDefaults.standard.double(forKey: "autoBackupIntervalHours")
        let interval = max(intervalHours, 1) * 3600
        autoBackupCancellable = Timer
            .publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performAutoBackup()
            }
        // Check if backup is overdue on setup
        let lastTimestamp = UserDefaults.standard.double(forKey: "lastAutoBackupDate")
        if lastTimestamp > 0 {
            let elapsed = Date().timeIntervalSince1970 - lastTimestamp
            if elapsed > interval { performAutoBackup() }
        } else {
            performAutoBackup()
        }
    }

    private func performAutoBackup() {
        Task {
            do {
                _ = try PersistenceService.createBackup()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastAutoBackupDate")
                JSONStorageService.cleanupOldBackups()
            } catch {
                logError(AppLog.persistence, "Auto-backup failed: \(error)")
            }
        }
    }

    // MARK: - Command Actions (called from menu commands)
    // Uses NotificationCenter so commands work even before ContentView's onAppear.

    func openHelp() { isShowingHelp = true }

    func commandOpenPDF() { NotificationCenter.default.post(name: .commandOpenPDF, object: nil) }
    func commandImportPDFs() { NotificationCenter.default.post(name: .commandImportPDFs, object: nil) }
    func commandToggleLibrary() { NotificationCenter.default.post(name: .commandToggleLibrary, object: nil) }
    func commandToggleNotes() { NotificationCenter.default.post(name: .commandToggleNotes, object: nil) }
    func commandToggleSearch() { NotificationCenter.default.post(name: .commandToggleSearch, object: nil) }

    func commandClosePDF() {
        tabManager.closeActiveTab()
    }

    func commandCaptureHighlight() {
        pdfController.captureHighlightToNotes()
    }

    func commandHighlightSelection() {
        pdfController.highlightSelection()
    }

    func commandUnderlineSelection() {
        pdfController.underlineSelection()
    }

    func commandStrikethroughSelection() {
        pdfController.strikethroughSelection()
    }

    func commandAddStickyNote() {
        pdfController.addStickyNote()
    }

    func commandExportAnnotatedPDF() {
        pdfController.exportAnnotatedPDF()
    }

    func commandShowProperties() {
        isShowingProperties = true
    }

    func commandRotateRight() {
        pdfController.rotateCurrentPageRight()
    }

    func commandRotateLeft() {
        pdfController.rotateCurrentPageLeft()
    }

    func commandRemoveAnnotationsOnPage() {
        pdfController.annotationManager.removeAnnotationsOnCurrentPage()
    }

    // MARK: - Text-to-Speech Commands

    func commandReadAloud() {
        guard let doc = pdfController.document else { return }
        if ttsService.isSpeaking {
            ttsService.stop()
        } else {
            ttsService.startReading(document: doc, fromPage: pdfController.currentPageIndex)
        }
    }

    func commandReadCurrentPage() {
        guard let doc = pdfController.document else { return }
        ttsService.readCurrentPage(document: doc, pageIndex: pdfController.currentPageIndex)
    }

    func commandPauseSpeech() {
        if ttsService.isPaused {
            ttsService.resume()
        } else {
            ttsService.pause()
        }
    }

    func commandStopSpeech() {
        ttsService.stop()
    }

    func commandShowFormFields() {
        isShowingFormFields = true
    }

    func commandShowAnnotations() {
        isShowingAnnotations = true
    }

    func commandCompareDocument() {
        guard pdfController.document != nil else { return }
        isShowingComparison = true
    }

    func commandPrintPDF() {
        pdfController.printDocument()
    }

    func commandToggleBookmark() {
        guard pdfController.document != nil else { return }
        pdfController.bookmarkManager.toggleBookmark(
            pdfController.currentPageIndex,
            for: pdfController.currentPDFURL
        )
        let isNowBookmarked = pdfController.bookmarkManager.bookmarks.contains(pdfController.currentPageIndex)
        enhancedToastCenter.showSuccess(
            isNowBookmarked ? "Bookmark Added" : "Bookmark Removed",
            "Page \(pdfController.currentPageIndex + 1)"
        )
    }

    /// Retains the current sketch window to prevent deallocation.
    private var currentSketchWindow: SketchWindow?

    func commandExportAnnotationsMarkdown() {
        AnnotationExportService.exportMarkdown(from: pdfController, notesStore: notesStore)
    }

    func commandGoBack() {
        pdfController.goBack()
    }

    func commandGoForward() {
        pdfController.goForward()
    }

    func commandAddSignature() {
        guard pdfController.document != nil else { return }
        isShowingSignaturePad = true
    }

    func commandNewSketchPage() {
        guard let url = pdfController.currentPDFURL else { return }
        let pageIndex = pdfController.currentPageIndex
        let sketchWindow = SketchWindow(
            size: CGSize(width: 800, height: 600),
            pdfURL: url,
            pageIndex: pageIndex,
            sketchStore: sketchStore
        ) { [weak self] _ in
            self?.currentSketchWindow = nil
        }
        currentSketchWindow = sketchWindow
        sketchWindow.show()
    }
}
