// App/ContentView.swift
import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers
import AppKit

// Right panel tabs
enum RightTab: String { case notes, code, web }

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
                PDFViewRepresentable(pdf: appEnvironment.pdfController)
                    .onDrop(of: [.pdf], isTargeted: nil, perform: handlePDFDrop(_:))
                    .background(Color(NSColor.textBackgroundColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .errorOverlay(appEnvironment.errorMessageManager)
        }
        // Toasts (enhanced, non-modal)
        .enhancedToastOverlay(appEnvironment.enhancedToastCenter)

        // ===== Lifecycle =====
        .onAppear {
            columnVisibility = showingLibrary ? .all : .detailOnly
            setupAutosaveTimer()
            wireMenuNotifications()
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

    // MARK: - Menu Notification Wiring
    /// Subscribes to the command notifications posted by DevReaderApp's .commands
    private func wireMenuNotifications() {
        guard cancellables.isEmpty else { return }
        NotificationCenter.default.publisher(for: .openPDF)
            .sink { _ in openPDF() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .importPDFs)
            .sink { _ in importPDFs() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .closePDF)
            .sink { _ in appEnvironment.pdfController.document = nil }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .toggleLibrary)
            .sink { _ in
                withAnimation {
                    showingLibrary.toggle()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .toggleNotes)
            .sink { _ in
                withAnimation {
                    showingRightPanel = true
                }
                rightTab = .notes
            }
            .store(in: &cancellables)

        // TODO: Search toggle is not yet implemented — the Cmd+F menu item
        // posts .toggleSearch but there is no search panel to show/hide yet.

        NotificationCenter.default.publisher(for: .captureHighlight)
            .sink { _ in appEnvironment.pdfController.captureHighlightToNotes() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .addStickyNote)
            .sink { _ in appEnvironment.pdfController.addStickyNote() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .showHelp)
            .sink { _ in appEnvironment.openHelp() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .showOnboarding)
            .sink { _ in appEnvironment.isShowingOnboarding = true }
            .store(in: &cancellables)

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
