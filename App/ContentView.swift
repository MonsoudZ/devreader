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
				CompactLayoutView(
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
					onOpenFromLibrary: openFromLibrary
				)
			} else {
				FullLayoutView(
					pdf: pdf,
					notes: notes,
					library: library,
					showingLibrary: $showingLibrary,
					showingRightPanel: $showingRightPanel,
					showingOutline: $showingOutline,
					collapseAll: $collapseAll,
					rightTab: $rightTab,
					showSearchPanel: $showSearchPanel,
					onOpenFromLibrary: openFromLibrary
				)
			}
			// Full-screen loading overlay when a PDF is loading
			if pdf.isLoadingPDF {
				ZStack {
					Color.black.opacity(0.2).ignoresSafeArea()
					VStack(spacing: 12) {
						ProgressView().scaleEffect(1.2)
						Text("Loading PDF…").font(.callout).foregroundStyle(.secondary)
						
						// Large PDF status information
						if pdf.isLargePDF {
							VStack(spacing: 4) {
								Text("Large PDF detected")
									.font(.caption)
									.foregroundStyle(.secondary)
								if !pdf.estimatedLoadTime.isEmpty {
									Text("Estimated time: \(pdf.estimatedLoadTime)")
										.font(.caption2)
										.foregroundStyle(.secondary)
								}
								if !pdf.memoryUsage.isEmpty {
									Text("Memory: \(pdf.memoryUsage)")
										.font(.caption2)
										.foregroundStyle(.secondary)
								}
							}
							.padding(.top, 8)
						}
					}
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .captureHighlight)) { _ in captureHighlightToNotes() }
		.onReceive(NotificationCenter.default.publisher(for: .newSketchPage)) { _ in newSketchPage() }
		.onReceive(NotificationCenter.default.publisher(for: .addStickyNote)) { _ in addStickyNote() }
		.onReceive(NotificationCenter.default.publisher(for: .closePDF)) { _ in closePDF() }
		.onReceive(NotificationCenter.default.publisher(for: .pdfLoadError)) { notification in
			if let url = notification.object as? URL {
				showErrorRecoveryDialog(for: url)
			}
		}
        .onChange(of: defaultZoom) { _, _ in applyZoomChange() }
		.onReceive(autosaveTimer) { _ in if autoSave { pdf.saveAnnotatedCopy() } }
		.onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in if autoSave { pdf.saveAnnotatedCopy() } }
        .onChange(of: autosaveIntervalSeconds) { _, _ in recreateAutosaveTimer() }
		.toolbar {
			ToolbarItemGroup {
				Button("Import PDFs…") { importPDFs() }
					.accessibilityLabel("Import PDFs")
					.accessibilityHint("Import multiple PDF files into your library")
				Button("Open PDF…") { openPDF() }
					.accessibilityLabel("Open PDF")
					.accessibilityHint("Open a single PDF file")
				Divider()
				Button(pdf.isBookmarked(pdf.currentPageIndex) ? "Remove Bookmark" : "Add Bookmark") { 
					pdf.toggleBookmark(pdf.currentPageIndex) 
				}
				.disabled(pdf.document == nil)
				.accessibilityLabel(pdf.isBookmarked(pdf.currentPageIndex) ? "Remove Bookmark" : "Add Bookmark")
				.accessibilityHint("Toggle bookmark for current page")
				Divider()
				Button(showingLibrary ? "Hide Library" : "Show Library") { showingLibrary.toggle() }
					.accessibilityLabel(showingLibrary ? "Hide Library" : "Show Library")
					.accessibilityHint("Toggle library panel visibility")
				Button(showingOutline ? "Hide Outline" : "Show Outline") { showingOutline.toggle() }
					.accessibilityLabel(showingOutline ? "Hide Outline" : "Show Outline")
					.accessibilityHint("Toggle outline panel visibility")
				Button(collapseAll ? "Expand All" : "Collapse All") { 
					collapseAll.toggle()
					if collapseAll {
						showingLibrary = false
						showingRightPanel = false
						showingOutline = false
					} else {
						showingLibrary = true
						showingRightPanel = true
						showingOutline = true
					}
				}
				.accessibilityLabel(collapseAll ? "Expand All" : "Collapse All")
				.accessibilityHint("Toggle all panels visibility")
				Spacer()
				
				// Recent Documents menu
				Menu("Recent") {
					if !pdf.pinnedDocuments.isEmpty {
						Section("Pinned") {
							ForEach(pdf.pinnedDocuments, id: \.self) { url in
								Button(url.lastPathComponent) { pdf.load(url: url) }
							}
						}
					}
					
					if !pdf.recentDocuments.isEmpty {
						Section("Recent") {
							ForEach(pdf.recentDocuments, id: \.self) { url in
								Button(url.lastPathComponent) { pdf.load(url: url) }
							}
						}
					}
					
					if !pdf.pinnedDocuments.isEmpty || !pdf.recentDocuments.isEmpty {
						Divider()
						Button("Clear Recents") { pdf.clearRecents() }
					}
					
					// Pin/Unpin current document
					if let currentURL = pdf.document?.documentURL {
						Divider()
						if pdf.isPinned(currentURL) {
							Button("Unpin Current Document") { pdf.unpin(currentURL) }
						} else {
							Button("Pin Current Document") { pdf.pin(currentURL) }
						}
					}
				}
				.disabled(pdf.pinnedDocuments.isEmpty && pdf.recentDocuments.isEmpty)
				
				Button("Settings…") { showSettings() }
			}
			
			// Search toolbar
			ToolbarItemGroup(placement: .primaryAction) {
                       TextField("Search PDF...", text: $pdf.searchQuery)
                           .textFieldStyle(.roundedBorder)
                           .frame(width: 200)
                           .onSubmit { 
                               if pdf.isLargePDF {
                                   pdf.performSearchOptimized(pdf.searchQuery)
                               } else {
                                   pdf.performSearch(pdf.searchQuery)
                               }
                           }
                           .accessibilityLabel("Search PDF")
                           .accessibilityHint("Enter text to search within the current PDF")
                       
                       Button("Find") { 
                           if pdf.isLargePDF {
                               pdf.performSearchOptimized(pdf.searchQuery)
                           } else {
                               pdf.performSearch(pdf.searchQuery)
                           }
                       }
					.keyboardShortcut("f", modifiers: [.command])
					.accessibilityLabel("Find")
					.accessibilityHint("Search for text in the PDF")

				if pdf.isSearching {
					ProgressView().controlSize(.small)
				}
				
				// Search results counter
				if !pdf.searchResults.isEmpty {
					Text("\(pdf.searchIndex + 1) of \(pdf.searchResults.count)")
						.font(.caption)
						.foregroundStyle(.secondary)
						.frame(minWidth: 60)
						.accessibilityLabel("Search results")
						.accessibilityValue("\(pdf.searchIndex + 1) of \(pdf.searchResults.count) results")
				}
				
				Button("Previous") { pdf.previousSearchResult() }
					.keyboardShortcut(.upArrow, modifiers: [.command])
					.disabled(pdf.searchResults.isEmpty)
					.accessibilityLabel("Previous search result")
					.accessibilityHint("Go to previous search result")
				
				Button("Next") { pdf.nextSearchResult() }
					.keyboardShortcut(.downArrow, modifiers: [.command])
					.disabled(pdf.searchResults.isEmpty)
					.accessibilityLabel("Next search result")
					.accessibilityHint("Go to next search result")
				
				Button("Clear") { pdf.clearSearch() }
					.disabled(pdf.searchResults.isEmpty)
					.accessibilityLabel("Clear search")
					.accessibilityHint("Clear search results")
			}
		}
		.sheet(isPresented: $showingSettings) { SettingsView() }
		.sheet(isPresented: $showingOnboarding) { OnboardingView() }
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
			Button("Open Different PDF") {
				openPDF()
			}
			Button("Recover Session") {
				pdf.recoverFromCorruption()
				toastCenter.show("Session Recovery", "Cleared corrupted session data", style: .success)
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("The PDF could not be opened. You can try again, open a different file, or recover your session.")
		}
		.toastOverlay(toastCenter)
	}
	
	// Actions previously inside ContentView
	func importPDFs() {
		let urls = FileService.openPDF(multiple: true)
		if !urls.isEmpty { library.add(urls: urls) }
	}
	func openPDF() {
		let urls = FileService.openPDF(multiple: false)
		if let url = urls.first { pdf.load(url: url) }
	}
	func captureHighlightToNotes() {
		guard let selection = PDFSelectionBridge.shared.currentSelection,
			  let doc = pdf.document,
			  let page = selection.pages.first else {
			toastCenter.show("No Selection", "Please select text in the PDF first", style: .warning)
			return
		}
		
		let pageIndex = doc.index(for: page)
		let text = selection.string ?? ""
		let chapter = pdf.outlineMap[pageIndex] ?? ""
		
		// Create a new note from the selection
		let note = NoteItem(
			text: text,
			pageIndex: pageIndex,
			chapter: chapter,
			tags: []
		)
		
		notes.add(note)
		
		// Create highlight annotation
		let highlightColor = getHighlightColor()
		let annotation = PDFAnnotation(bounds: selection.bounds(for: page), forType: .highlight, withProperties: nil)
		annotation.color = highlightColor
		page.addAnnotation(annotation)
		
		// Save annotated copy
		if autoSave { pdf.saveAnnotatedCopy() }
		
		toastCenter.show("Highlight Added", "Text captured as note", style: .success)
	}
	func newSketchPage() {
		guard pdf.document != nil else {
			toastCenter.show("No PDF", "Please open a PDF first", style: .warning)
			return
		}
		
		let pageSize = CGSize(width: 800, height: 600)
		let sketchWindow = SketchWindow(size: pageSize) { image in
			Task { @MainActor in
				await self.insertSketchImage(image)
			}
		}
		sketchWindow.show()
	}
	
	func insertSketchImage(_ image: NSImage) async {
		guard let doc = pdf.document,
			  let page = doc.page(at: pdf.currentPageIndex) else {
			toastCenter.show("No PDF", "Please open a PDF first", style: .warning)
			return
		}
		
		// Convert NSImage to PDF annotation
		let pageBounds = page.bounds(for: .mediaBox)
		let imageSize = image.size
		let scale = min(pageBounds.width / imageSize.width, pageBounds.height / imageSize.height) * 0.5
		let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
		let imageBounds = CGRect(
			x: pageBounds.midX - scaledSize.width / 2,
			y: pageBounds.midY - scaledSize.height / 2,
			width: scaledSize.width,
			height: scaledSize.height
		)
		
		// Create freeText annotation with sketch content
		let annotation = PDFAnnotation(bounds: imageBounds, forType: .freeText, withProperties: nil)
		annotation.contents = "Sketch: \(imageSize.width)x\(imageSize.height)"
		annotation.color = NSColor.systemBlue
		
		page.addAnnotation(annotation)
		
		// Save annotated copy
		if autoSave { pdf.saveAnnotatedCopy() }
		
		toastCenter.show("Sketch Added", "Sketch annotation added to PDF", style: .success)
	}
	func addStickyNote() {
		guard let doc = pdf.document,
			  let page = doc.page(at: pdf.currentPageIndex) else {
			toastCenter.show("No PDF", "Please open a PDF first", style: .warning)
			return
		}
		
		// Create a sticky note annotation at the center of the current page
		let pageBounds = page.bounds(for: .mediaBox)
		let noteBounds = CGRect(x: pageBounds.midX - 50, y: pageBounds.midY - 50, width: 100, height: 100)
		
		let annotation = PDFAnnotation(bounds: noteBounds, forType: .freeText, withProperties: nil)
		annotation.contents = "Double-click to edit this note"
		annotation.color = NSColor.systemYellow
		page.addAnnotation(annotation)
		
		// Create a note item for the sticky note
		let note = NoteItem(
			text: "Sticky note on page \(pdf.currentPageIndex + 1)",
			pageIndex: pdf.currentPageIndex,
			chapter: pdf.outlineMap[pdf.currentPageIndex] ?? "",
			tags: ["sticky"]
		)
		
		notes.add(note)
		
		// Save annotated copy
		if autoSave { pdf.saveAnnotatedCopy() }
		
		toastCenter.show("Sticky Note Added", "Note created on current page", style: .success)
	}
	func closePDF() { pdf.clearSession() }
	func showSettings() { showingSettings = true }
	func checkFirstLaunch() { if !UserDefaults.standard.bool(forKey: "DevReader.HasLaunchedBefore") { showingOnboarding = true; UserDefaults.standard.set(true, forKey: "DevReader.HasLaunchedBefore") } }
	func showAlert(_ title: String, _ message: String) { alertTitle = title; alertMessage = message; showingAlert = true }
	
	func getHighlightColor() -> NSColor {
		switch highlightColor {
		case "yellow": return NSColor.systemYellow
		case "green": return NSColor.systemGreen
		case "blue": return NSColor.systemBlue
		case "red": return NSColor.systemRed
		case "orange": return NSColor.systemOrange
		case "purple": return NSColor.systemPurple
		default: return NSColor.systemYellow
		}
	}
	func openFromLibrary(_ item: LibraryItem) {
		guard FileManager.default.fileExists(atPath: item.url.path) else { 
			showAlert("File Not Found", "The PDF file could not be found. It may have been moved or deleted.")
			toastCenter.show("File Not Found", item.url.lastPathComponent, style: .error)
			return 
		}
		guard let testDoc = PDFDocument(url: item.url), testDoc.pageCount > 0 else { 
			showAlert("Cannot Open PDF", "The file may be corrupted or not a valid PDF.")
			toastCenter.show("Cannot Open PDF", item.url.lastPathComponent, style: .error)
			return 
		}
		pdf.load(url: item.url)
	}
	
	func showErrorRecoveryDialog(for url: URL) {
		errorRecoveryAction = {
			// Retry loading the PDF
			pdf.load(url: url)
		}
		showingErrorRecovery = true
		toastCenter.show("PDF Error", "Failed to open \(url.lastPathComponent)", style: .error)
	}
	
	// Apply zoom instantly when defaultZoom changes
	@MainActor
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
