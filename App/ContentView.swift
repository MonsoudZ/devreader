import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AppKit

enum RightTab { case notes, code, web }

struct ContentView: View {
	@StateObject private var pdf = PDFController()
	@StateObject private var notes = NotesStore()
	@StateObject private var library = LibraryStore()

	@State private var rightTab: RightTab = .notes
	@State private var showingSettings = false
	@State private var showingOnboarding = false
	@State private var alertMessage = ""
	@State private var alertTitle = ""
	@State private var showingAlert = false
	@State private var showingLibrary = false
	@State private var showingRightPanel = true

	var body: some View {
		GeometryReader { geometry in
			if geometry.size.width < 1000 {
				VStack(spacing: 0) {
					HStack {
						Button("Library") { showingLibrary = !showingLibrary }.buttonStyle(.bordered)
						Spacer()
						Picker("", selection: $rightTab) {
							Text("Notes").tag(RightTab.notes)
							Text("Code").tag(RightTab.code)
							Text("Web").tag(RightTab.web)
						}
						.pickerStyle(.segmented)
						.frame(maxWidth: 200)
						Button(showingRightPanel ? "Hide Panel" : "Show Panel") { showingRightPanel.toggle() }.buttonStyle(.bordered)
					}
					.padding(8)
					.background(Color(NSColor.controlBackgroundColor))
					Divider()
					HStack(spacing: 0) {
						if showingLibrary {
							LibraryPane(library: library, pdf: pdf) { item in openFromLibrary(item) }
							.frame(width: 260)
						}
						PDFPane(pdf: pdf, notes: notes)
						if showingRightPanel {
							Divider()
							VStack(spacing: 0) {
								switch rightTab {
								case .notes: NotesPane(pdf: pdf, notes: notes)
								case .code:  CodePane()
								case .web:   WebPane()
								}
							}
							.frame(minWidth: 300, idealWidth: 400)
						}
					}
				}
			} else {
				HSplitView {
					LibraryPane(library: library, pdf: pdf) { item in openFromLibrary(item) }
						.frame(minWidth: 220, idealWidth: 260)
					PDFPane(pdf: pdf, notes: notes).frame(minWidth: 400)
					VStack(spacing: 0) {
						Picker("", selection: $rightTab) {
							Text("Notes").tag(RightTab.notes)
							Text("Code").tag(RightTab.code)
							Text("Web").tag(RightTab.web)
						}
						.pickerStyle(.segmented)
						.padding(8)
						Divider()
						switch rightTab {
						case .notes: NotesPane(pdf: pdf, notes: notes)
						case .code:  CodePane()
						case .web:   WebPane()
						}
					}
					.frame(minWidth: 300, idealWidth: 400)
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .captureHighlight)) { _ in captureHighlightToNotes() }
		.onReceive(NotificationCenter.default.publisher(for: .newSketchPage)) { _ in newSketchPage() }
		.onReceive(NotificationCenter.default.publisher(for: .addStickyNote)) { _ in addStickyNote() }
		.onReceive(NotificationCenter.default.publisher(for: .closePDF)) { _ in closePDF() }
		.toolbar {
			ToolbarItemGroup {
				Button("Import PDFs…") { importPDFs() }
				Button("Open PDF…") { openPDF() }
				if pdf.document != nil {
					Button("Close PDF") { closePDF() }
					Divider()
					Button("Highlight → Note") { captureHighlightToNotes() }
					Button("New Sketch Page") { newSketchPage() }
					Button("Add Sticky Note") { addStickyNote() }
					Button(pdf.isBookmarked(pdf.currentPageIndex) ? "Remove Bookmark" : "Add Bookmark") { pdf.toggleBookmark(pdf.currentPageIndex) }
				}
				Button("Settings…") { showSettings() }
			}
		}
		.sheet(isPresented: $showingSettings) { SettingsView() }
		.sheet(isPresented: $showingOnboarding) { OnboardingView() }
		.onAppear {
			checkFirstLaunch()
			pdf.onPDFChanged = { url in notes.setCurrentPDF(url) }
		}
		.alert(alertTitle, isPresented: $showingAlert) { Button("OK") { } } message: { Text(alertMessage) }
	}
	
	// Actions previously inside ContentView
	func importPDFs() { let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType.pdf]; panel.allowsMultipleSelection = true; if panel.runModal() == .OK { library.add(urls: panel.urls) } }
	func openPDF() { let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType.pdf]; if panel.runModal() == .OK, let url = panel.urls.first { pdf.load(url: url) } }
	func captureHighlightToNotes() { NotificationCenter.default.post(name: .captureHighlight, object: nil) }
	func newSketchPage() { NotificationCenter.default.post(name: .newSketchPage, object: nil) }
	func addStickyNote() { NotificationCenter.default.post(name: .addStickyNote, object: nil) }
	func closePDF() { pdf.clearSession() }
	func showSettings() { showingSettings = true }
	func checkFirstLaunch() { if !UserDefaults.standard.bool(forKey: "DevReader.HasLaunchedBefore") { showingOnboarding = true; UserDefaults.standard.set(true, forKey: "DevReader.HasLaunchedBefore") } }
	func showAlert(_ title: String, _ message: String) { alertTitle = title; alertMessage = message; showingAlert = true }
	func openFromLibrary(_ item: LibraryItem) {
		guard FileManager.default.fileExists(atPath: item.url.path) else { showAlert("File Not Found", "The PDF file could not be found. It may have been moved or deleted."); return }
		guard let testDoc = PDFDocument(url: item.url), testDoc.pageCount > 0 else { showAlert("Cannot Open PDF", "The file may be corrupted or not a valid PDF."); return }
		pdf.load(url: item.url)
	}
}
