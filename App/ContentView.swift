import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers
import AppKit

enum RightTab { case notes, code, web }

struct ContentView: View {
	@EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var toastCenter: ToastCenter
	@AppStorage("defaultZoom") private var defaultZoom: Double = 1.0
	@AppStorage("highlightColor") private var highlightColor: String = "yellow"
	@AppStorage("autoSave") private var autoSave: Bool = true
	@AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30
	@State private var autosaveTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

	@State private var rightTab: RightTab = .notes
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
    
    // Computed property to derive rightTab from rightTabRaw
    private var computedRightTab: RightTab {
        get {
            switch rightTabRaw {
            case "code": return .code
            case "web": return .web
            default: return .notes
            }
        }
        set {
            switch newValue {
            case .notes: rightTabRaw = "notes"
            case .code: rightTabRaw = "code"
            case .web: rightTabRaw = "web"
            }
        }
    }
    
    // Helper function to update rightTabRaw
    private func updateRightTabRaw(_ newTab: RightTab) {
        switch newTab {
        case .notes: rightTabRaw = "notes"
        case .code: rightTabRaw = "code"
        case .web: rightTabRaw = "web"
        }
    }

	var body: some View {
		mainContent
			.modifier(ContentViewModifiers())
			.enhancedToastOverlay(appEnvironment.enhancedToastCenter)
			.errorOverlay(appEnvironment.errorMessageManager)
			.sheet(isPresented: Binding(
				get: { appEnvironment.isShowingSettings },
				set: { appEnvironment.isShowingSettings = $0 }
			)) {
				SettingsView()
			}
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
			pdf: appEnvironment.pdfController,
			notes: appEnvironment.notesStore,
			library: appEnvironment.libraryStore,
			showingLibrary: $showingLibrary,
			showingRightPanel: $showingRightPanel,
			showingOutline: $showingOutline,
			collapseAll: $collapseAll,
			rightTab: Binding(
				get: { computedRightTab },
				set: { updateRightTabRaw($0) }
			),
			showSearchPanel: $showSearchPanel,
			showingSettings: $appEnvironment.isShowingSettings,
			onOpenFromLibrary: openFromLibrary,
			onImportPDFs: importPDFs,
			onOpenPDF: openPDF
		)
	}
	
	@ViewBuilder
	private var fullLayout: some View {
		ModernFullLayoutView(
			pdf: appEnvironment.pdfController,
			notes: appEnvironment.notesStore,
			library: appEnvironment.libraryStore,
			showingLibrary: $showingLibrary,
			showingRightPanel: $showingRightPanel,
			showingOutline: $showingOutline,
			collapseAll: $collapseAll,
			rightTab: $rightTab,
			showSearchPanel: $showSearchPanel,
			showingSettings: $appEnvironment.isShowingSettings,
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
			appEnvironment.libraryStore.add(urls: urls)
			appEnvironment.enhancedToastCenter.showSuccess("PDFs Added", "Added \(urls.count) PDF\(urls.count == 1 ? "" : "s") to library", category: .fileOperation)
		} else {
			appEnvironment.enhancedToastCenter.showInfo("No PDFs Selected", "Please select one or more PDF files to import", category: .userAction)
		}
	}
	func openPDF() {
		let urls = FileService.openPDF(multiple: false)
		if let url = urls.first { 
			appEnvironment.pdfController.load(url: url)
			appEnvironment.enhancedToastCenter.showInfo("PDF Opened", "Loading \(url.lastPathComponent)", category: .fileOperation)
		} else {
			appEnvironment.enhancedToastCenter.showInfo("No PDF Selected", "Please select a PDF file to open", category: .userAction)
		}
	}
	func openFromLibrary(_ item: LibraryItem) {
		appEnvironment.pdfController.load(url: item.url)
		appEnvironment.enhancedToastCenter.showInfo("PDF Opened", "Loading \(item.url.lastPathComponent)", category: .fileOperation)
	}
	func closePDF() {
		appEnvironment.pdfController.document = nil
		appEnvironment.enhancedToastCenter.showInfo("PDF Closed", "Document closed", category: .userAction)
	}
	func captureHighlightToNotes() {
		// Implementation for capturing highlights to notes
		appEnvironment.pdfController.captureHighlightToNotes()
	}
	func newSketchPage() {
		guard let pdfURL = appEnvironment.pdfController.currentPDFURL else {
			appEnvironment.enhancedToastCenter.showWarning("No PDF", "Please open a PDF first", category: .userAction)
			return
		}
		
		let pageSize = CGSize(width: 800, height: 600)
		let pageIndex = appEnvironment.pdfController.currentPageIndex
		
		let sketchWindow = SketchWindow(
			size: pageSize,
			pdfURL: pdfURL,
			pageIndex: pageIndex
		) { image in
			Task { @MainActor in
				// Insert the sketch image into the PDF or save it
				appEnvironment.enhancedToastCenter.showSuccess("Sketch Created", "Sketch saved to page \(pageIndex + 1)", category: .userAction)
			}
		}
		sketchWindow.show()
	}
	func addStickyNote() {
		// Implementation for adding sticky note
		appEnvironment.pdfController.addStickyNote()
	}
	func showErrorRecoveryDialog(for url: URL) {
		// Use enhanced error handling
		appEnvironment.enhancedToastCenter.showPDFLoadingError(for: url, error: NSError(domain: "DevReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDF loading failed"]))
	}
	func checkFirstLaunch() {
		// Check if this is the first launch and show onboarding
		let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
		if !hasLaunchedBefore {
			appEnvironment.isShowingOnboarding = true
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
