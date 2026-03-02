// App/ContentView.swift
import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers
import AppKit

// Right panel tabs
enum RightTab { case notes, code, web }

struct ContentView: View {
    // MARK: - Environment & App Config
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var toastCenter: ToastCenter  // kept for compatibility with existing toasts
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.0
    @AppStorage("highlightColor") private var highlightColor: String = "yellow"
    @AppStorage("autoSave") private var autoSave: Bool = true
    @AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30

    // Persisted UI toggles
    @AppStorage("ui.showingLibrary") private var showingLibrary = true
    @AppStorage("ui.showingRightPanel") private var showingRightPanel = true

    // MARK: - Local UI State
    @State private var rightTab: RightTab = .notes
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // Autosave timer: we recreate it whenever the interval changes
    @State private var autosaveCancellable: AnyCancellable?
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            // ===== Main split layout =====
            HStack(spacing: 0) {
                // Left: Library list (optional)
                if showingLibrary {
                    LibraryPane(
                        library: appEnvironment.libraryStore,
                        pdf: appEnvironment.pdfController,
                        open: { item in
                            appEnvironment.pdfController.open(url: item.url)
                            NotificationCenter.default.post(name: .currentPDFURLDidChange, object: nil, userInfo: ["url": item.url])
                        }
                    )
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                    .overlay(dividerVertical, alignment: .trailing)
                }

                // Center: PDF + header
                VStack(spacing: 0) {
                    // Header bar with common actions (optional polish; use your existing header if desired)
                    headerBar

                    // The PDF view
                    PDFViewRepresentable(pdf: appEnvironment.pdfController)
                        .onDrop(of: [.pdf], isTargeted: nil, perform: handlePDFDrop(_:))
                        .background(Color(NSColor.textBackgroundColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
                .overlay(dividerVertical, alignment: .trailing)

                // Right: Tools (Notes / Code / Web)
                if showingRightPanel {
                    rightSidebar
                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                }
            }
            .frame(minHeight: 400)

            // ===== Global UX overlays =====
            LoadingOverlay() // unified loading spinner layer
            // Enhanced error overlay (modal-style)
            // (kept non-intrusive; shows when ErrorMessageManager has an error)
            // .errorOverlay is defined in Views/Error/ErrorDisplayView.swift
            .errorOverlay(appEnvironment.errorMessageManager)
        }
        // Toasts (enhanced, non-modal)
        .enhancedToastOverlay(appEnvironment.enhancedToastCenter)

        // ===== Lifecycle =====
        .onAppear {
            setupAutosaveTimer()
            wireMenuNotifications()
        }
        .onChange(of: autosaveIntervalSeconds) { _ in
            // Rebuild timer when the interval changes
            setupAutosaveTimer()
        }
        .onChange(of: autoSave) { _ in
            // If autosave was disabled/enabled, rebuild to honor new state
            setupAutosaveTimer()
        }

        // ===== Alerts =====
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { showingAlert = false }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                openPDF()
            } label: {
                Label("Open", systemImage: "folder")
            }

            Button {
                importPDFs()
            } label: {
                Label("Import", systemImage: "tray.and.arrow.down")
            }

            Spacer()

            // Library toggle
            Toggle(isOn: $showingLibrary) {
                Image(systemName: "books.vertical")
                    .help("Toggle Library")
            }
            .toggleStyle(.button)

            // Right pane toggle
            Toggle(isOn: $showingRightPanel) {
                Image(systemName: "sidebar.right")
                    .help("Toggle Tools")
            }
            .toggleStyle(.button)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(dividerHorizontal, alignment: .bottom)
    }

    // MARK: - Right Sidebar (Notes / Code / Web)
    private var rightSidebar: some View {
        VStack(spacing: 0) {
            // Segmented control for tabs
            Picker("", selection: $rightTab) {
                Text("Notes").tag(RightTab.notes)
                Text("Code").tag(RightTab.code)
                Text("Web").tag(RightTab.web)
            }
            .pickerStyle(.segmented)
            .padding(8)
            .overlay(dividerHorizontal, alignment: .bottom)

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
    /// Subscribes to the command notifications posted by DevReaderApp’s .commands
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
            .sink { _ in showingLibrary.toggle() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .toggleNotes)
            .sink { _ in
                showingRightPanel = true
                rightTab = .notes
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .toggleSearch)
            .sink { _ in
                // If you have a Search panel view, toggle it here.
                // For now, we surface a toast for UX feedback.
                appEnvironment.enhancedToastCenter.showInfo("Search", "Press ⌘F to search within the PDF.")
            }
            .store(in: &cancellables)

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
    }

    // MARK: - Autosave
    /// Builds (or rebuilds) the autosave timer based on user settings.
    private func setupAutosaveTimer() {
        autosaveCancellable?.cancel()
        guard autoSave, autosaveIntervalSeconds > 0.5 else { return }

        // Recreate a timer publisher with the current interval
        autosaveCancellable = Timer
            .publish(every: autosaveIntervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { @MainActor in
                    // Notes: NotesStore persists on mutations; this is a “checkpoint” hook.
                    // Library: do a background save so large libraries don’t block UI.
                    await SimpleBackgroundPersistenceService.shared.saveLibraryItems(appEnvironment.libraryStore.items)
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
            // Ensure we're on the main thread for @MainActor state access
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
                    LoadingStateManager.shared.startImport("Importing PDFs…")
                    defer { LoadingStateManager.shared.stopImport() }
                    _ = await SimpleBackgroundPersistenceService.shared.importPDFs(urls)
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

    // MARK: - Separators
    private var dividerVertical: some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(width: 1)
    }

    private var dividerHorizontal: some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(height: 1)
    }
}

// Notification.Name definitions live in Utils/Extensions.swift (single source of truth).