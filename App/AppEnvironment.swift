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

    // MARK: - Sheet Toggles
    @Published var isShowingOnboarding = false
    @Published var isShowingSettings = false
    @Published var isShowingHelp = false

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

        // Wire PDF changes to notes store
        pdf.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        // Restore last-opened PDF after init completes and wiring is in place
        Task { @MainActor in
            pdf.restoreLastOpenedPDF()
        }
    }

    // MARK: - Convenience

    func openHelp() {
        isShowingHelp = true
    }
}
