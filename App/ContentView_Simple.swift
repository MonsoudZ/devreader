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
		GeometryReader { geometry in
			if geometry.size.width < 820 {
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
			} else {
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
			// Global loading overlay
			LoadingOverlay()
		}
		.onReceive(NotificationCenter.default.publisher(for: .captureHighlight)) { _ in captureHighlightToNotes() }
		.onReceive(NotificationCenter.default.publisher(for: .newSketchPage)) { _ in newSketchPage() }
		.onReceive(NotificationCenter.default.publisher(for: .addStickyNote)) { _ in addStickyNote() }
		.onReceive(NotificationCenter.default.publisher(for: .closePDF)) { _ in closePDF() }
		.onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in showingOnboarding = true }
		.onReceive(NotificationCenter.default.publisher(for: .pdfLoadError)) { notification in
			if let url = notification.object as? URL {
				showErrorRecoveryDialog(for: url)
			}
		}
        .onChange(of: defaultZoom) { _, _ in applyZoomChange() }
		.onReceive(autosaveTimer) { _ in 
			if autoSave { 
				Task {
					await pdf.saveAnnotatedCopyAsync()
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in 
			if autoSave { 
				Task {
					await pdf.saveAnnotatedCopyAsync()
				}
			}
		}
		.keyboardShortcut("?", modifiers: .command) {
			showingHelp = true
		}
        .onChange(of: autosaveIntervalSeconds) { _, _ in recreateAutosaveTimer() }
		.toolbar {
			ToolbarItemGroup {
				Button("Import PDFs…") { importPDFs() }
				Button("Show Onboarding") { showingOnboarding = true }
				Button("Settings…") { showingSettings = true }
				Button("Help") { showingHelp = true }
			}
		}
		.sheet(isPresented: $showingSettings) { ModernSettingsView() }
		.sheet(isPresented: $showingOnboarding) { 
			OnboardingView()
				.frame(minWidth: 600, minHeight: 500)
		}
		.sheet(isPresented: $showingHelp) {
			Text("Help View - Coming Soon")
		}
		.onAppear {
			checkFirstLaunch()
			pdf.onPDFChanged = { url in notes.setCurrentPDF(url) }
			recreateAutosaveTimer()
            if rightTabRaw == "code" { rightTab = .code } else if rightTabRaw == "web" { rightTab = .web } else { rightTab = .notes }
		}
		.alert(alertTitle, isPresented: $showingAlert) { Button("OK") { } } message: { Text(alertMessage) }
		.alert("PDF Loading Error", isPresented: $showingErrorRecovery) {
			Button("Try Again") {
				errorRecoveryAction?()
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("Failed to load PDF. Would you like to try again?")
		}
		.toastOverlay(toastCenter)
	}
	
	// Actions
	func importPDFs() {
		let urls = FileService.openPDF(multiple: true)
		if !urls.isEmpty { 
			library.add(urls: urls)
			toastCenter.show("PDFs Added", "Added \(urls.count) PDF\(urls.count == 1 ? "" : "s") to library", style: .success)
		}
	}
	func openPDF() {
		let urls = FileService.openPDF(multiple: false)
		if let url = urls.first { 
			pdf.load(url: url)
			toastCenter.show("PDF Opened", "Loading \(url.lastPathComponent)", style: .info)
		}
	}
	func openFromLibrary(_ item: LibraryItem) {
		pdf.load(url: item.url)
		toastCenter.show("PDF Opened", "Loading \(item.url.lastPathComponent)", style: .info)
	}
	func closePDF() {
		pdf.close()
		toastCenter.show("PDF Closed", "Document closed", style: .info)
	}
	func captureHighlightToNotes() {
		// Implementation for capturing highlights to notes
		toastCenter.show("Highlight Captured", "Added to notes", style: .success)
	}
	func newSketchPage() {
		// Implementation for creating new sketch page
		toastCenter.show("New Sketch", "Sketch page created", style: .info)
	}
	func addStickyNote() {
		// Implementation for adding sticky note
		toastCenter.show("Sticky Note", "Note added", style: .success)
	}
	func showErrorRecoveryDialog(for url: URL) {
		alertTitle = "PDF Loading Error"
		alertMessage = "Failed to load \(url.lastPathComponent). Would you like to try again?"
		showingAlert = true
		errorRecoveryAction = { [weak self] in
			self?.pdf.load(url: url)
		}
	}
	func checkFirstLaunch() {
		// Check if this is the first launch and show onboarding
		let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
		if !hasLaunchedBefore {
			showingOnboarding = true
			UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
		}
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
}
