//
//  DevReaderApp.swift
//  DevReader
//
//  App entry point: boots persistence, injects shared environment/services,
//  hosts ContentView, surfaces init errors, and defines app-wide commands.
//

import SwiftUI
import PDFKit
import Combine
import AppKit
import CoreSpotlight

// MARK: - App
@main
struct DevReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Shared app-wide state (stores, controllers, services)
    @StateObject private var appEnvironment = AppEnvironment()              // DevReaderApp owns the single instance
    @StateObject private var shortcuts = KeyboardShortcutStore.shared
    // Legacy ToastCenter removed — all toasts now use EnhancedToastCenter

    // App appearance
    @AppStorage("appAppearance") private var appAppearance: String = "system"

    // Init error surfacing
    @State private var initializationError: String?
    @State private var showingErrorAlert = false

    // macOS scene phase for lifecycle hooks (suspend/resume)
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Bootstrap
    init() {
        // Initialize base persistence layer early; store message for later alert if it fails.
        PersistenceService.initialize()
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            // Root view
            ContentView()
                // Shared state
                .environmentObject(appEnvironment)

                // App-wide appearance based on user preference
                .preferredColorScheme(preferredScheme)

                // Window sizing baseline (macOS)
                .frame(minWidth: 780, minHeight: 520)

                // First appearance: show any init error we captured in init()
                .onAppear {
                    checkInitializationError()
                    appEnvironment.setupAutoBackupTimer()
                }

                // Handle Spotlight search result clicks
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }

                // Present global sheets based on AppEnvironment toggles
                .sheet(isPresented: $appEnvironment.isShowingOnboarding) {
                    OnboardingView()
                        .environmentObject(appEnvironment)
                        .frame(minWidth: 800, minHeight: 560)
                }
                .sheet(isPresented: $appEnvironment.isShowingSettings) {
                    SettingsView()
                        .environmentObject(appEnvironment)
                        .frame(minWidth: 720, minHeight: 520)
                }
                .sheet(isPresented: $appEnvironment.isShowingHelp) {
                    HelpView()
                        .environmentObject(appEnvironment)
                        .frame(minWidth: 820, minHeight: 600)
                }
                .sheet(isPresented: $appEnvironment.isShowingAbout) {
                    AboutView(isPresented: $appEnvironment.isShowingAbout)
                }
                .sheet(isPresented: $appEnvironment.isShowingProperties) {
                    PDFPropertiesView(properties: appEnvironment.pdfController.documentProperties())
                        .frame(minWidth: 400, minHeight: 300)
                }
                .sheet(isPresented: $appEnvironment.isShowingFormFields) {
                    PDFFormView(pdf: appEnvironment.pdfController)
                        .frame(minWidth: 350, minHeight: 400)
                }
                .sheet(isPresented: $appEnvironment.isShowingAnnotations) {
                    AnnotationListView(pdf: appEnvironment.pdfController)
                        .frame(minWidth: 350, minHeight: 400)
                }

                // Hard fail alert (only for init-time persistence failure)
                .alert("Initialization Error", isPresented: $showingErrorAlert) {
                    Button("OK") {
                        showingErrorAlert = false
                        clearInitializationError()
                    }
                    Button("Retry") { retryInitialization() }
                } message: {
                    Text(initializationError ?? "An unknown error occurred during app initialization.")
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        // MARK: - App-wide Commands (Menus)
        .commands {
            // File Menu
            CommandGroup(after: .newItem) {
                Button("Open PDF…") { appEnvironment.commandOpenPDF() }
                    .keyboardShortcut(shortcuts.binding(for: .openPDF).keyEquivalent, modifiers: shortcuts.binding(for: .openPDF).modifiers)
                    .accessibilityLabel("Open PDF")

                Button("Import PDFs…") { appEnvironment.commandImportPDFs() }
                    .keyboardShortcut(shortcuts.binding(for: .importPDFs).keyEquivalent, modifiers: shortcuts.binding(for: .importPDFs).modifiers)
                    .accessibilityLabel("Import PDFs")

                Divider()

                Button("New Sketch Page") { appEnvironment.commandNewSketchPage() }
                    .keyboardShortcut(shortcuts.binding(for: .newSketch).keyEquivalent, modifiers: shortcuts.binding(for: .newSketch).modifiers)
                    .accessibilityLabel("New Sketch Page")

                Divider()

                Button("Export PDF with Annotations…") { appEnvironment.commandExportAnnotatedPDF() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .accessibilityLabel("Export annotated PDF")
                    .accessibilityHint("Save a copy of the PDF with all annotations embedded")

                Divider()

                Button("Print…") { appEnvironment.commandPrintPDF() }
                    .keyboardShortcut("p", modifiers: [.command])
                    .accessibilityLabel("Print PDF")
            }

            // Edit Menu
            CommandGroup(after: .textEditing) {
                Button("Highlight Selection") { appEnvironment.commandHighlightSelection() }
                    .keyboardShortcut(shortcuts.binding(for: .highlightSelection).keyEquivalent, modifiers: shortcuts.binding(for: .highlightSelection).modifiers)
                    .accessibilityLabel("Highlight Selection")

                Button("Underline Selection") { appEnvironment.commandUnderlineSelection() }
                    .keyboardShortcut(shortcuts.binding(for: .underlineSelection).keyEquivalent, modifiers: shortcuts.binding(for: .underlineSelection).modifiers)
                    .accessibilityLabel("Underline Selection")

                Button("Strikethrough Selection") { appEnvironment.commandStrikethroughSelection() }
                    .keyboardShortcut(shortcuts.binding(for: .strikethroughSelection).keyEquivalent, modifiers: shortcuts.binding(for: .strikethroughSelection).modifiers)
                    .accessibilityLabel("Strikethrough Selection")

                Button("Highlight → Note") { appEnvironment.commandCaptureHighlight() }
                    .keyboardShortcut(shortcuts.binding(for: .captureHighlight).keyEquivalent, modifiers: shortcuts.binding(for: .captureHighlight).modifiers)
                    .accessibilityLabel("Capture Highlight to Note")

                Button("Add Sticky Note") { appEnvironment.commandAddStickyNote() }
                    .keyboardShortcut(shortcuts.binding(for: .addStickyNote).keyEquivalent, modifiers: shortcuts.binding(for: .addStickyNote).modifiers)
                    .accessibilityLabel("Add Sticky Note")

                Divider()

                Button("Toggle Page Bookmark") { appEnvironment.commandToggleBookmark() }
                    .keyboardShortcut(shortcuts.binding(for: .toggleBookmark).keyEquivalent, modifiers: shortcuts.binding(for: .toggleBookmark).modifiers)
                    .accessibilityLabel("Toggle Page Bookmark")
            }

            // View Menu
            CommandGroup(after: .appVisibility) {
                Button("Toggle Search") { appEnvironment.commandToggleSearch() }
                    .keyboardShortcut(shortcuts.binding(for: .toggleSearch).keyEquivalent, modifiers: shortcuts.binding(for: .toggleSearch).modifiers)
                    .accessibilityLabel("Toggle Search")

                Button("Toggle Library") { appEnvironment.commandToggleLibrary() }
                    .keyboardShortcut(shortcuts.binding(for: .toggleLibrary).keyEquivalent, modifiers: shortcuts.binding(for: .toggleLibrary).modifiers)
                    .accessibilityLabel("Toggle Library")

                Button("Toggle Notes") { appEnvironment.commandToggleNotes() }
                    .keyboardShortcut(shortcuts.binding(for: .toggleNotes).keyEquivalent, modifiers: shortcuts.binding(for: .toggleNotes).modifiers)
                    .accessibilityLabel("Toggle Notes")

                Divider()

                Button("Zoom In") { appEnvironment.pdfController.zoomIn() }
                    .keyboardShortcut("+", modifiers: [.command])
                    .accessibilityLabel("Zoom in")

                Button("Zoom Out") { appEnvironment.pdfController.zoomOut() }
                    .keyboardShortcut("-", modifiers: [.command])
                    .accessibilityLabel("Zoom out")

                Button("Actual Size") { appEnvironment.pdfController.zoomActualSize() }
                    .keyboardShortcut("0", modifiers: [.command])
                    .accessibilityLabel("Actual size")

                Button("Zoom to Fit") { appEnvironment.pdfController.zoomToFit() }
                    .keyboardShortcut("9", modifiers: [.command])
                    .accessibilityLabel("Zoom to fit")

                Divider()

                Button("Next Page") { appEnvironment.pdfController.goToNextPage() }
                    .keyboardShortcut(.downArrow, modifiers: [.command])
                    .accessibilityLabel("Next page")

                Button("Previous Page") { appEnvironment.pdfController.goToPreviousPage() }
                    .keyboardShortcut(.upArrow, modifiers: [.command])
                    .accessibilityLabel("Previous page")

                Divider()

                Button("Rotate Page Right") { appEnvironment.commandRotateRight() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .accessibilityLabel("Rotate page right")

                Button("Rotate Page Left") { appEnvironment.commandRotateLeft() }
                    .keyboardShortcut("r", modifiers: [.command, .shift, .option])
                    .accessibilityLabel("Rotate page left")

                Divider()

                Button("Document Properties\u{2026}") { appEnvironment.commandShowProperties() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .accessibilityLabel("Document properties")

                Button("Form Fields\u{2026}") { appEnvironment.commandShowFormFields() }
                    .accessibilityLabel("Show form fields")

                Divider()

                Button("Annotations\u{2026}") { appEnvironment.commandShowAnnotations() }
                    .accessibilityLabel("Show annotation list")

                Button("Remove Annotations on Page") { appEnvironment.commandRemoveAnnotationsOnPage() }
                    .accessibilityLabel("Remove annotations on current page")

                Divider()

                Button(appEnvironment.ttsService.isSpeaking ? "Stop Reading Aloud" : "Read Aloud from Here") {
                    appEnvironment.commandReadAloud()
                }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .accessibilityLabel("Read aloud")

                Button("Read Current Page") { appEnvironment.commandReadCurrentPage() }
                    .accessibilityLabel("Read current page aloud")

                if appEnvironment.ttsService.isSpeaking || appEnvironment.ttsService.isPaused {
                    Button(appEnvironment.ttsService.isPaused ? "Resume Speech" : "Pause Speech") {
                        appEnvironment.commandPauseSpeech()
                    }
                        .keyboardShortcut(".", modifiers: [.command])
                        .accessibilityLabel("Pause or resume speech")
                }

                Divider()

                Button("Close PDF") { appEnvironment.commandClosePDF() }
                    .keyboardShortcut(shortcuts.binding(for: .closePDF).keyEquivalent, modifiers: shortcuts.binding(for: .closePDF).modifiers)
                    .accessibilityLabel("Close PDF")
            }

            // Help Menu
            CommandGroup(after: .help) {
                Button("Show Help") { appEnvironment.openHelp() }
                    .keyboardShortcut("?", modifiers: [.command])
                    .accessibilityLabel("Show Help")
                    .accessibilityHint("Open the help documentation")

                Button("Show Onboarding") { appEnvironment.isShowingOnboarding = true }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .accessibilityLabel("Show Onboarding")
                    .accessibilityHint("Show the getting started guide")

                Divider()

                Button("About DevReader") { appEnvironment.isShowingAbout = true }
                    .accessibilityLabel("About DevReader")
                    .accessibilityHint("Show information about DevReader")
            }
        }
        // MARK: - Lifecycle Hooks
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Index library for Spotlight on first activation
                SpotlightService.shared.indexLibraryItems(appEnvironment.libraryStore.items)
            case .inactive, .background:
                // Flush any pending debounced persistence
                appEnvironment.pdfController.flushPendingPersistence()
                appEnvironment.pdfController.annotationManager.flushPendingPersistence()
                appEnvironment.libraryStore.flushPendingPersistence()
                appEnvironment.notesStore.flushPendingPersistence()
                appEnvironment.sketchStore.flushPendingPersistence()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Appearance
    private var preferredScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // MARK: - Init Error Handling
    private func checkInitializationError() {
        if let error = UserDefaults.standard.string(forKey: "initializationError") {
            initializationError = error
            showingErrorAlert = true
        }
    }

    private func clearInitializationError() {
        UserDefaults.standard.removeObject(forKey: "initializationError")
        initializationError = nil
    }

    private func retryInitialization() {
        clearInitializationError()
        PersistenceService.initialize()
        appEnvironment.enhancedToastCenter.showSuccess(
            "Initialization Succeeded",
            "App storage and services are ready.",
            category: .system
        )
    }

    // MARK: - Spotlight

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }

        if let itemID = SpotlightService.libraryItemID(from: identifier) {
            // Open the PDF from library
            if let item = appEnvironment.libraryStore.items.first(where: { $0.id == itemID }) {
                appEnvironment.pdfController.load(libraryItem: item)
            }
        }
        // Note results will open the app; the note is visible in the notes pane
    }
}
