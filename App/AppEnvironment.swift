import Foundation
import SwiftUI
import Combine

/// Central app-wide state container. Holds shared controllers, stores, and UI services.
/// Injected via `@EnvironmentObject` from `DevReaderApp`.
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    // MARK: - Core Controllers & Stores
    let pdfController: PDFController
    let libraryStore: LibraryStore
    let notesStore: NotesStore
    let sketchStore: SketchStore

    // MARK: - UI Services
    let enhancedToastCenter: EnhancedToastCenter
    let errorMessageManager: ErrorMessageManager
    let loadingStateManager: LoadingStateManager
    let performanceMonitor: PerformanceMonitor

    // MARK: - Sheet Toggles
    @Published var isShowingOnboarding = false
    @Published var isShowingSettings = false
    @Published var isShowingHelp = false
    @Published var isShowingAbout = false

    // MARK: - Init
    private init() {
        let pdf = PDFController()
        let library = LibraryStore()
        let notes = NotesStore()

        self.pdfController = pdf
        self.libraryStore = library
        self.notesStore = notes
        self.sketchStore = SketchStore()
        self.enhancedToastCenter = EnhancedToastCenter()
        self.errorMessageManager = ErrorMessageManager.shared
        self.loadingStateManager = LoadingStateManager.shared
        self.performanceMonitor = PerformanceMonitor.shared

        // Wire PDF changes to notes store
        pdf.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        // Restore last-opened PDF after init completes and wiring is in place
        Task { @MainActor in
            pdf.restoreLastOpenedPDF()
        }
    }

    // MARK: - Command Signals
    // Monotonic counters that ContentView observes via onChange to react to menu commands
    // that require local-state changes (toggles, panels, file dialogs).
    @Published var openPDFSignal = 0
    @Published var importPDFsSignal = 0
    @Published var toggleLibrarySignal = 0
    @Published var toggleNotesSignal = 0
    @Published var toggleSearchSignal = 0

    // MARK: - Command Actions (called from menu commands)

    func openHelp() { isShowingHelp = true }

    func commandOpenPDF() { openPDFSignal += 1 }
    func commandImportPDFs() { importPDFsSignal += 1 }
    func commandToggleLibrary() { toggleLibrarySignal += 1 }
    func commandToggleNotes() { toggleNotesSignal += 1 }
    func commandToggleSearch() { toggleSearchSignal += 1 }

    func commandClosePDF() {
        pdfController.document = nil
    }

    func commandCaptureHighlight() {
        pdfController.captureHighlightToNotes()
    }

    func commandAddStickyNote() {
        pdfController.addStickyNote()
    }

    /// Retains the current sketch window to prevent deallocation.
    private var currentSketchWindow: SketchWindow?

    func commandNewSketchPage() {
        guard let url = pdfController.currentPDFURL else { return }
        let pageIndex = pdfController.currentPageIndex
        let sketchWindow = SketchWindow(
            size: CGSize(width: 800, height: 600),
            pdfURL: url,
            pageIndex: pageIndex
        ) { [weak self] _ in
            self?.currentSketchWindow = nil
        }
        currentSketchWindow = sketchWindow
        sketchWindow.show()
    }
}
