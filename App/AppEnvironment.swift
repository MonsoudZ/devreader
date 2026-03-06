import Foundation
import SwiftUI
import Combine

/// Central app-wide state container. Holds shared controllers, stores, and UI services.
/// Injected via `@EnvironmentObject` from `DevReaderApp`.
@MainActor
final class AppEnvironment: ObservableObject {

    // MARK: - Core Controllers & Stores
    private(set) var pdfController: PDFController
    private(set) var libraryStore: LibraryStore
    private(set) var notesStore: NotesStore
    private(set) var sketchStore: SketchStore

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

    // MARK: - Init
    init(
        loadingStateManager: LoadingStateManager = .shared,
        performanceMonitor: PerformanceMonitor = .shared,
        errorMessageManager: ErrorMessageManager = ErrorMessageManager()
    ) {
        self.loadingStateManager = loadingStateManager
        self.performanceMonitor = performanceMonitor
        self.errorMessageManager = errorMessageManager

        let pdf = PDFController(loadingStateManager: loadingStateManager, performanceMonitor: performanceMonitor)
        let library = LibraryStore(loadingStateManager: loadingStateManager)
        let notes = NotesStore()

        self.pdfController = pdf
        self.libraryStore = library
        self.notesStore = notes
        self.sketchStore = SketchStore()
        self.enhancedToastCenter = EnhancedToastCenter()

        // Wire PDF changes to notes store
        pdf.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        // Restore last-opened PDF after init completes and wiring is in place
        Task { @MainActor in
            pdf.restoreLastOpenedPDF()
        }
    }

    // MARK: - Command Callbacks
    // Closures registered by ContentView to handle menu commands
    var onOpenPDF: (@MainActor () -> Void)?
    var onImportPDFs: (@MainActor () -> Void)?
    var onToggleLibrary: (@MainActor () -> Void)?
    var onToggleNotes: (@MainActor () -> Void)?
    var onToggleSearch: (@MainActor () -> Void)?

    // MARK: - Command Actions (called from menu commands)

    func openHelp() { isShowingHelp = true }

    func commandOpenPDF() { onOpenPDF?() }
    func commandImportPDFs() { onImportPDFs?() }
    func commandToggleLibrary() { onToggleLibrary?() }
    func commandToggleNotes() { onToggleNotes?() }
    func commandToggleSearch() { onToggleSearch?() }

    func commandClosePDF() {
        pdfController.document = nil
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

    func commandPrintPDF() {
        pdfController.printDocument()
    }

    func commandToggleBookmark() {
        guard pdfController.document != nil else { return }
        pdfController.bookmarkManager.toggleBookmark(
            pdfController.currentPageIndex,
            for: pdfController.currentPDFURL
        )
    }

    /// Retains the current sketch window to prevent deallocation.
    private var currentSketchWindow: SketchWindow?

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
