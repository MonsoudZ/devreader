// App/ContentView.swift
import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers
import AppKit

// Right panel tabs — raw values are stored by @AppStorage; do not rename without migration.
nonisolated enum RightTab: String {
    case notes, code, web
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
    @State private var showingThumbnails = false
    @State private var showingSplitView = false
    @State private var showingFormFields = false

    // Autosave timer: we recreate it whenever the interval changes
    @State private var autosaveCancellable: AnyCancellable?

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
                    toastCenter: appEnvironment.enhancedToastCenter,
                    open: { item in
                        appEnvironment.tabManager.openInTab(libraryItem: item)
                    }
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
            } detail: {
                // Center: Tab bar + PDF viewer with optional thumbnail pane
                VStack(spacing: 0) {
                if appEnvironment.tabManager.showTabBar {
                    PDFTabBar(tabManager: appEnvironment.tabManager)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                HStack(spacing: 0) {
                    if showingThumbnails, appEnvironment.pdfController.document != nil {
                        PDFThumbnailPane(pdf: appEnvironment.pdfController)
                            .frame(width: 160)
                            .transition(.move(edge: .leading))
                        Divider()
                    }

                ZStack {
                    if showingSplitView {
                        PDFSplitView(
                            primaryPDF: appEnvironment.pdfController,
                            secondaryPDF: appEnvironment.secondaryPDFController,
                            isSplitActive: $showingSplitView
                        )
                        .onDrop(of: [.pdf], isTargeted: nil, perform: handlePDFDrop(_:))
                        .background(Color(NSColor.textBackgroundColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        PDFViewRepresentable(pdf: appEnvironment.pdfController)
                            .onDrop(of: [.pdf], isTargeted: nil, perform: handlePDFDrop(_:))
                            .background(Color(NSColor.textBackgroundColor))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack {
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

                        Spacer()

                        HStack(alignment: .bottom) {
                            if appEnvironment.pdfController.document != nil {
                                PDFToolbar(pdf: appEnvironment.pdfController)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            if appEnvironment.ttsService.isSpeaking || appEnvironment.ttsService.isPaused {
                                ttsControls
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 8)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showingSearch)
                .animation(.easeInOut(duration: 0.2), value: showingSplitView)
                .animation(.easeInOut(duration: 0.2), value: appEnvironment.pdfController.document != nil)
                }
                .animation(.easeInOut(duration: 0.2), value: showingThumbnails)
                }
                .animation(.easeInOut(duration: 0.15), value: appEnvironment.tabManager.showTabBar)
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
                                    showingThumbnails.toggle()
                                }
                            } label: {
                                Label("Thumbnails", systemImage: "rectangle.grid.1x2")
                            }
                            .help("Toggle Page Thumbnails")
                            .accessibilityIdentifier("toggleThumbnails")

                            Button {
                                withAnimation {
                                    showingSplitView.toggle()
                                }
                            } label: {
                                Label("Split View", systemImage: "rectangle.split.2x1")
                            }
                            .help("Toggle Split View")
                            .accessibilityIdentifier("toggleSplitView")

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

        }
        // Menu command notifications (fire even before onAppear)
        .onReceive(NotificationCenter.default.publisher(for: .commandOpenPDF)) { _ in
            openPDF()
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandImportPDFs)) { _ in
            importPDFs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandToggleLibrary)) { _ in
            withAnimation { showingLibrary.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandToggleNotes)) { _ in
            withAnimation { showingRightPanel = true }
            rightTab = .notes
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandToggleSearch)) { _ in
            let wasShowing = showingSearch
            withAnimation { showingSearch.toggle() }
            if wasShowing {
                appEnvironment.pdfController.searchManager.clearSearch()
            }
        }
        // Internal event publishers from PDFController (replace NotificationCenter)
        .onReceive(appEnvironment.pdfController.pdfLoadErrorPublisher) { error in
            appEnvironment.enhancedToastCenter.showError(
                "PDF Load Failed",
                "\(error.url.lastPathComponent): \(error.reason)",
                category: .fileOperation,
                duration: 6
            )
        }
        .onReceive(appEnvironment.pdfController.noteRequestPublisher) { note in
            appEnvironment.notesStore.add(note)
        }
        .onReceive(appEnvironment.pdfController.toastRequestPublisher) { toast in
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
        .onReceive(NotificationCenter.default.publisher(for: CopyAwarePDFView.didCopyNotification)) { _ in
            appEnvironment.enhancedToastCenter.showSuccess("Copied", "Text copied to clipboard")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecentFromDock)) { notification in
            if let url = notification.object as? URL {
                appEnvironment.tabManager.openInTab(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearRecentsFromDock)) { _ in
            appEnvironment.pdfController.bookmarkManager.clearRecents()
        }
        .onReceive(appEnvironment.notesStore.persistenceFailurePublisher) { message in
            appEnvironment.enhancedToastCenter.showError("Save Failed", message, duration: 6)
        }
        .onChange(of: showingLibrary) { _, newValue in
            withAnimation {
                columnVisibility = newValue ? .all : .detailOnly
            }
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
            Picker("Right panel", selection: $rightTab) {
                Label("Notes", systemImage: "note.text").labelStyle(.iconOnly).help("Notes").tag(RightTab.notes)
                Label("Code", systemImage: "chevron.left.forwardslash.chevron.right").labelStyle(.iconOnly).help("Code").tag(RightTab.code)
                Label("Web", systemImage: "globe").labelStyle(.iconOnly).help("Web").tag(RightTab.web)
            }
            .pickerStyle(.segmented)
            .padding(12)
            .accessibilityIdentifier("rightTabPicker")
            .accessibilityLabel("Right panel tab selector")

            // Tab content
            Group {
                switch rightTab {
                case .notes:
                    NotesPane(pdf: appEnvironment.pdfController, notes: appEnvironment.notesStore, bookmarkManager: appEnvironment.pdfController.bookmarkManager, outlineManager: appEnvironment.pdfController.outlineManager, toastCenter: appEnvironment.enhancedToastCenter)
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

    // MARK: - TTS Controls
    private var ttsControls: some View {
        HStack(spacing: 8) {
            Button {
                appEnvironment.commandPauseSpeech()
            } label: {
                Image(systemName: appEnvironment.ttsService.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
            .help(appEnvironment.ttsService.isPaused ? "Resume" : "Pause")
            .accessibilityLabel(appEnvironment.ttsService.isPaused ? "Resume reading" : "Pause reading")

            Button {
                appEnvironment.commandStopSpeech()
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
            .help("Stop")
            .accessibilityLabel("Stop reading")

            Text("Reading page \(appEnvironment.ttsService.currentPage + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: -2)
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
                    await appEnvironment.libraryStore.backgroundService.saveLibraryItems(appEnvironment.libraryStore.items)
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
                appEnvironment.tabManager.openInTab(url: url)
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
                    appEnvironment.loadingStateManager.startImport("Importing PDFs\u{2026}")
                    defer { appEnvironment.loadingStateManager.stopImport() }
                    _ = await appEnvironment.libraryStore.backgroundService.importPDFs(urls)
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
                    appEnvironment.tabManager.openInTab(url: url)
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
        .onAppear {
            isFocused = true
            if query.isEmpty { searchManager.clearSearch() }
        }
        .onDisappear { query = "" }
    }

    private func search() {
        searchManager.performSearch(query, in: document)
    }
}
