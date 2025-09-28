import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers
import AppKit

enum RightTab { case notes, code, web }

struct ContentView: View {
	@StateObject private var pdf = PDFController()
	@StateObject private var notes = NotesStore()
	@StateObject private var library = LibraryStore()
    @EnvironmentObject private var toastCenter: ToastCenter
    @StateObject private var enhancedToastCenter = EnhancedToastCenter()
    @StateObject private var errorMessageManager = ErrorMessageManager.shared
	@AppStorage("defaultZoom") private var defaultZoom: Double = 1.0
	@AppStorage("highlightColor") private var highlightColor: String = "yellow"
	@AppStorage("autoSave") private var autoSave: Bool = true
	@AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30
	@State private var autosaveTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    @State private var rightTab: RightTab = .notes
	@State private var showingSettings = false
	@State private var showingOnboarding = false
	@State private var showingHelp = false
	@State private var alertMessage = ""
	@State private var alertTitle = ""
	@State private var showingAlert = false
	@State private var showingErrorRecovery = false
	@State private var errorRecoveryAction: (() -> Void)?
    @AppStorage("ui.showingLibrary") private var showingLibrary = true
	@AppStorage("ui.showingRightPanel") private var showingRightPanel = true
	@AppStorage("ui.showingOutline") private var showingOutline = true
	@AppStorage("ui.rightTab") private var rightTabRaw = "notes"
    @AppStorage("ui.showSearchPanel") private var showSearchPanel = true
    @AppStorage("ui.collapseAll") private var collapseAll = false

	var body: some View {
		mainContent
			.modifier(ContentViewModifiers())
			.enhancedToastOverlay(enhancedToastCenter)
			.errorOverlay(errorMessageManager)
	}
	
	@ViewBuilder
	private var mainContent: some View {
		GeometryReader { geometry in
			layoutContent(for: geometry)
			// Global loading overlay
			LoadingOverlay()
		}
	}
	
	@ViewBuilder
	private func layoutContent(for geometry: GeometryProxy) -> some View {
		if geometry.size.width < 820 {
			compactLayout
		} else {
			fullLayout
		}
	}
	
	@ViewBuilder
	private var compactLayout: some View {
		ModernCompactLayoutView(
			pdf: pdf,
			notes: notes,
			library: library,
			showingLibrary: $showingLibrary,
			showingRightPanel: $showingRightPanel,
			showingOutline: $showingOutline,
			collapseAll: $collapseAll,
			rightTab: $rightTab,
			rightTabRaw: $rightTabRaw,
			showSearchPanel: $showSearchPanel,
			showingSettings: $showingSettings,
			onOpenFromLibrary: openFromLibrary,
			onImportPDFs: importPDFs,
			onOpenPDF: openPDF
		)
	}
	
	@ViewBuilder
	private var fullLayout: some View {
		ModernFullLayoutView(
			pdf: pdf,
			notes: notes,
			library: library,
			showingLibrary: $showingLibrary,
			showingRightPanel: $showingRightPanel,
			showingOutline: $showingOutline,
			collapseAll: $collapseAll,
			rightTab: $rightTab,
			showSearchPanel: $showSearchPanel,
			showingSettings: $showingSettings,
			onOpenFromLibrary: openFromLibrary,
			onImportPDFs: importPDFs,
			onOpenPDF: openPDF
		)
	}
	func applyZoomChange() {
		if let view = PDFSelectionBridge.shared.pdfView, defaultZoom > 0 {
			view.scaleFactor = defaultZoom
		}
	}
	@MainActor
	func recreateAutosaveTimer() {
		autosaveTimer = Timer.publish(every: autosaveIntervalSeconds, on: .main, in: .common).autoconnect()
	}
	
	// Actions
	func importPDFs() {
		let urls = FileService.openPDF(multiple: true)
		if !urls.isEmpty {
			library.add(urls: urls)
			enhancedToastCenter.showSuccess("PDFs Added", "Added \(urls.count) PDF\(urls.count == 1 ? "" : "s") to library", category: .fileOperation)
		} else {
			enhancedToastCenter.showInfo("No PDFs Selected", "Please select one or more PDF files to import", category: .userAction)
		}
	}
	func openPDF() {
		let urls = FileService.openPDF(multiple: false)
		if let url = urls.first { 
			pdf.load(url: url)
			enhancedToastCenter.showInfo("PDF Opened", "Loading \(url.lastPathComponent)", category: .fileOperation)
		} else {
			enhancedToastCenter.showInfo("No PDF Selected", "Please select a PDF file to open", category: .userAction)
		}
	}
	func openFromLibrary(_ item: LibraryItem) {
		pdf.load(url: item.url)
		enhancedToastCenter.showInfo("PDF Opened", "Loading \(item.url.lastPathComponent)", category: .fileOperation)
	}
	func closePDF() {
		pdf.document = nil
		enhancedToastCenter.showInfo("PDF Closed", "Document closed", category: .userAction)
	}
	func captureHighlightToNotes() {
		// Implementation for capturing highlights to notes
		enhancedToastCenter.showSuccess("Highlight Captured", "Added to notes", category: .userAction)
	}
	func newSketchPage() {
		// Implementation for creating new sketch page
		enhancedToastCenter.showInfo("New Sketch", "Sketch page created", category: .userAction)
	}
	func addStickyNote() {
		// Implementation for adding sticky note
		enhancedToastCenter.showSuccess("Sticky Note", "Note added", category: .userAction)
	}
	func showErrorRecoveryDialog(for url: URL) {
		// Use enhanced error handling
		enhancedToastCenter.showPDFLoadingError(for: url, error: NSError(domain: "DevReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDF loading failed"]))
	}
	func checkFirstLaunch() {
		// Check if this is the first launch and show onboarding
		let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
		if !hasLaunchedBefore {
			showingOnboarding = true
			UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
		}
	}
}

// MARK: - ContentView Modifiers

struct ContentViewModifiers: ViewModifier {
	func body(content: Content) -> some View {
		content
			.onReceive(NotificationCenter.default.publisher(for: .captureHighlight)) { _ in }
			.onReceive(NotificationCenter.default.publisher(for: .newSketchPage)) { _ in }
			.onReceive(NotificationCenter.default.publisher(for: .addStickyNote)) { _ in }
			.onReceive(NotificationCenter.default.publisher(for: .closePDF)) { _ in }
			.onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in }
			.keyboardShortcut("?", modifiers: .command)
			.toolbar { }
			.sheet(isPresented: .constant(false)) { Text("") }
			.onAppear { }
			.alert("", isPresented: .constant(false)) { }
			.toastOverlay(ToastCenter())
	}
}
