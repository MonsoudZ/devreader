// App/ContentView.swift
import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers
import AppKit

// Right panel tabs — raw values are stored by @AppStorage; do not rename without migration.
enum RightTab: String {
    case notes, code, web

    /// Resilient initializer: maps unknown stored values to `.notes` instead of nil,
    /// preventing @AppStorage from silently discarding unrecognized persisted values.
    init(fromStored rawValue: String) {
        self = RightTab(rawValue: rawValue) ?? .notes
    }
}

struct ContentView: View {
    // MARK: - Environment & App Config
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @AppStorage("autoSave") private var autoSave: Bool = true
    @AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30

    // Persisted UI toggles
    @AppStorage("ui.showingLibrary") private var showingLibrary = true
    @AppStorage("ui.showingRightPanel") private var showingRightPanel = true

    // MARK: - Local UI State
    @AppStorage("ui.rightTab") private var rightTab: RightTab = .notes
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingSearch = false

    // Autosave timer: we recreate it whenever the interval changes
    @State private var autosaveCancellable: AnyCancellable?
    @State private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    private var documentTitle: String {
        guard let doc = appEnvironment.pdfController.document,
              let url = doc.documentURL else {
            return "DevReader"
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private var pageInfo: String {
        guard let doc = appEnvironment.pdfController.document, doc.pageCount > 0 else {
            return ""
        }
        return "Page \(appEnvironment.pdfController.currentPageIndex + 1) of \(doc.pageCount)"
    }

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // Left: Library sidebar
                LibraryPane(
                    library: appEnvironment.libraryStore,
                    pdf: appEnvironment.pdfController,
                    open: { item in
                        appEnvironment.pdfController.open(url: item.url)
                        NotificationCenter.default.post(name: .currentPDFURLDidChange, object: nil, userInfo: ["url": item.url])
                    }
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
            } detail: {
                // Center: PDF viewer
                ZStack(alignment: .top) {
                    PDFViewRepresentable(pdf: appEnvironment.pdfController)
                        .onDrop(of: [.pdf], isTargeted: nil, perform: handlePDFDrop(_:))
                        .background(Color(NSColor.textBackgroundColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showingSearch {
                        PDFSearchBar(
                            searchManager: appEnvironment.pdfController.searchManager,
                            document: appEnvironment.pdfController.document,
                            isLargePDF: appEnvironment.pdfController.isLargePDF,
                            onDismiss: {
                                showingSearch = false
                                appEnvironment.pdfController.searchManager.clearSearch()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showingSearch)
                    .navigationTitle(documentTitle)
                    .navigationSubtitle(pageInfo)
                    // Right: Tools inspector
                    .inspector(isPresented: $showingRightPanel) {
                        rightSidebar
                            .inspectorColumnWidth(min: 300, ideal: 360, max: 480)
                    }
                    // Native macOS toolbar
                    .toolbar {
                        ToolbarItemGroup(placement: .navigation) {
                            Button {
                                openPDF()
                            } label: {
                                Label("Open", systemImage: "folder")
                            }
                            .accessibilityIdentifier("openPDFButton")

                            Button {
                                importPDFs()
                            } label: {
                                Label("Import", systemImage: "tray.and.arrow.down")
                            }
                            .accessibilityIdentifier("importPDFButton")
                        }

                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                withAnimation {
                                    showingLibrary.toggle()
                                }
                            } label: {
                                Label("Library", systemImage: "books.vertical")
                            }
                            .help("Toggle Library")
                            .accessibilityIdentifier("toggleLibrary")

                            Button {
                                withAnimation {
                                    showingRightPanel.toggle()
                                }
                            } label: {
                                Label("Tools", systemImage: "sidebar.right")
                            }
                            .help("Toggle Tools")
                            .accessibilityIdentifier("toggleTools")
                        }
                    }
            }

            // ===== Global UX overlays =====
            LoadingOverlay()
        }
        // Toasts (enhanced, non-modal)
        .enhancedToastOverlay(appEnvironment.enhancedToastCenter)

        // ===== Lifecycle =====
        .onAppear {
            columnVisibility = showingLibrary ? .all : .detailOnly
            setupAutosaveTimer()
            wireInternalNotifications()
        }
        // Command signal observers (replace NotificationCenter-based menu routing)
        .onChange(of: appEnvironment.openPDFSignal) { _, _ in openPDF() }
        .onChange(of: appEnvironment.importPDFsSignal) { _, _ in importPDFs() }
        .onChange(of: appEnvironment.toggleLibrarySignal) { _, _ in
            withAnimation { showingLibrary.toggle() }
        }
        .onChange(of: appEnvironment.toggleNotesSignal) { _, _ in
            withAnimation { showingRightPanel = true }
            rightTab = .notes
        }
        .onChange(of: appEnvironment.toggleSearchSignal) { _, _ in
            let wasShowing = showingSearch
            withAnimation { showingSearch.toggle() }
            if wasShowing {
                appEnvironment.pdfController.searchManager.clearSearch()
            }
        }
        .onChange(of: showingLibrary) { _, newValue in
            withAnimation {
                columnVisibility = newValue ? .all : .detailOnly
            }
        }
        .onChange(of: columnVisibility) { _, newValue in
            showingLibrary = (newValue != .detailOnly)
        }
        .onChange(of: autosaveIntervalSeconds) { _, _ in
            setupAutosaveTimer()
        }
        .onChange(of: autoSave) { _, _ in
            setupAutosaveTimer()
        }
    }

    // MARK: - Right Sidebar (Notes / Code / Web)
    private var rightSidebar: some View {
        VStack(spacing: 0) {
            // Segmented control with SF Symbol icons
            Picker("", selection: $rightTab) {
                Label("Notes", systemImage: "note.text").tag(RightTab.notes)
                Label("Code", systemImage: "chevron.left.forwardslash.chevron.right").tag(RightTab.code)
                Label("Web", systemImage: "globe").tag(RightTab.web)
            }
            .pickerStyle(.segmented)
            .padding(12)
            .accessibilityIdentifier("rightTabPicker")

            // Tab content
            Group {
                switch rightTab {
                case .notes:
                    NotesPane(pdf: appEnvironment.pdfController, notes: appEnvironment.notesStore)
                case .code:
                    CodePane()
                case .web:
                    WebPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Internal Notification Wiring
    /// Subscribes to internal notifications (addNote, showToast, pdfLoadError) that are
    /// posted from various parts of the app — NOT from menu commands.
    private func wireInternalNotifications() {
        guard cancellables.isEmpty else { return }

        NotificationCenter.default.publisher(for: .addNote)
            .sink { notification in
                if let note = notification.object as? NoteItem {
                    appEnvironment.notesStore.add(note)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .showToast)
            .sink { notification in
                if let toast = notification.object as? ToastMessage {
                    switch toast.type {
                    case .success:
                        appEnvironment.enhancedToastCenter.showSuccess("Success", toast.message)
                    case .error:
                        appEnvironment.enhancedToastCenter.showError("Error", toast.message)
                    case .warning:
                        appEnvironment.enhancedToastCenter.showWarning("Warning", toast.message)
                    case .info:
                        appEnvironment.enhancedToastCenter.showInfo("Info", toast.message)
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .pdfLoadError)
            .sink { notification in
                let filename = (notification.object as? URL)?.lastPathComponent ?? "Unknown file"
                appEnvironment.enhancedToastCenter.showError(
                    "PDF Load Failed",
                    "Could not open \"\(filename)\". The file may be missing, corrupted, or inaccessible.",
                    category: .fileOperation,
                    duration: 6
                )
            }
            .store(in: &cancellables)
    }

    // MARK: - Autosave
    /// Builds (or rebuilds) the autosave timer based on user settings.
    private func setupAutosaveTimer() {
        autosaveCancellable?.cancel()
        guard autoSave, autosaveIntervalSeconds > 0.5 else { return }

        autosaveCancellable = Timer
            .publish(every: autosaveIntervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { @MainActor in
                    await LibraryPersistenceService.shared.saveLibraryItems(appEnvironment.libraryStore.items)
                }
            }
    }

    // MARK: - File Open / Import
    private func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { resp in
            DispatchQueue.main.async {
                guard resp == .OK, let url = panel.url else { return }
                appEnvironment.pdfController.open(url: url)
                NotificationCenter.default.post(name: .currentPDFURLDidChange, object: nil, userInfo: ["url": url])
                appEnvironment.libraryStore.add(urls: [url])
            }
        }
    }

    private func importPDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { resp in
            DispatchQueue.main.async {
                guard resp == .OK else { return }
                let urls = panel.urls
                Task { @MainActor in
                    LoadingStateManager.shared.startImport("Importing PDFs\u{2026}")
                    defer { LoadingStateManager.shared.stopImport() }
                    _ = await LibraryPersistenceService.shared.importPDFs(urls)
                    appEnvironment.libraryStore.add(urls: urls)
                }
            }
        }
    }

    // MARK: - Drag & Drop
    private func handlePDFDrop(_ providers: [NSItemProvider]) -> Bool {
        let pdfProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }
        guard !pdfProviders.isEmpty else { return false }

        for provider in pdfProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, _) in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                DispatchQueue.main.async {
                    appEnvironment.pdfController.open(url: url)
                    NotificationCenter.default.post(name: .currentPDFURLDidChange, object: nil, userInfo: ["url": url])
                    appEnvironment.libraryStore.add(urls: [url])
                }
            }
        }
        return true
    }
}

// MARK: - PDF Search Bar

private struct PDFSearchBar: View {
    @ObservedObject var searchManager: PDFSearchManager
    var document: PDFDocument?
    var isLargePDF: Bool
    var onDismiss: () -> Void

    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search in PDF…", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { search() }
                .accessibilityIdentifier("searchPDFField")
                .accessibilityLabel("Search PDF")

            if !searchManager.searchResults.isEmpty {
                Text("\(searchManager.searchIndex + 1) of \(searchManager.searchResults.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } else if searchManager.isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                searchManager.previousSearchResult(in: document)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(searchManager.searchResults.isEmpty)
            .accessibilityIdentifier("searchPrevious")
            .accessibilityLabel("Previous result")

            Button {
                searchManager.nextSearchResult(in: document)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(searchManager.searchResults.isEmpty)
            .accessibilityIdentifier("searchNext")
            .accessibilityLabel("Next result")

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("searchClose")
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .padding(.horizontal, 40)
        .padding(.top, 8)
        .onAppear { isFocused = true }
        .onDisappear { query = "" }
    }

    private func search() {
        if isLargePDF {
            searchManager.performSearchOptimized(query, in: document)
        } else {
            searchManager.performSearch(query, in: document)
        }
    }
}
