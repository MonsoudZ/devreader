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

// MARK: - App
@main
struct DevReaderApp: App {
    // Shared app-wide state (stores, controllers, services)
    @StateObject private var appEnvironment = AppEnvironment.shared        // central hub
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
                .onAppear(perform: checkInitializationError)

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
                Button("Open PDF…") { NotificationCenter.default.post(name: .openPDF, object: nil) }
                    .keyboardShortcut("o", modifiers: [.command])
                    .accessibilityLabel("Open PDF")
                    .accessibilityHint("Open an existing PDF file")

                Button("Import PDFs…") { NotificationCenter.default.post(name: .importPDFs, object: nil) }
                    .keyboardShortcut("i", modifiers: [.command])
                    .accessibilityLabel("Import PDFs")
                    .accessibilityHint("Import multiple PDF files into your library")

                Divider()

                Button("New Sketch Page") { NotificationCenter.default.post(name: .newSketchPage, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityLabel("New Sketch Page")
                    .accessibilityHint("Create a new sketch page for the current PDF")
            }

            // Edit Menu
            CommandGroup(after: .textEditing) {
                Button("Highlight → Note") { NotificationCenter.default.post(name: .captureHighlight, object: nil) }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                    .accessibilityLabel("Capture Highlight to Note")
                    .accessibilityHint("Convert selected text to a note")

                Button("Add Sticky Note") { NotificationCenter.default.post(name: .addStickyNote, object: nil) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .accessibilityLabel("Add Sticky Note")
                    .accessibilityHint("Add a sticky note to the current page")
            }

            // View Menu
            CommandGroup(after: .appVisibility) {
                Button("Toggle Search") { NotificationCenter.default.post(name: .toggleSearch, object: nil) }
                    .keyboardShortcut("f", modifiers: [.command])
                    .accessibilityLabel("Toggle Search")
                    .accessibilityHint("Show or hide the search panel")

                Button("Toggle Library") { NotificationCenter.default.post(name: .toggleLibrary, object: nil) }
                    .keyboardShortcut("l", modifiers: [.command])
                    .accessibilityLabel("Toggle Library")
                    .accessibilityHint("Show or hide the library panel")

                Button("Toggle Notes") { NotificationCenter.default.post(name: .toggleNotes, object: nil) }
                    .keyboardShortcut("t", modifiers: [.command])
                    .accessibilityLabel("Toggle Notes")
                    .accessibilityHint("Show or hide the notes panel")

                Divider()

                Button("Close PDF") { NotificationCenter.default.post(name: .closePDF, object: nil) }
                    .keyboardShortcut("w", modifiers: [.command])
                    .accessibilityLabel("Close PDF")
                    .accessibilityHint("Close the currently open PDF")
            }

            // Help Menu
            CommandGroup(after: .help) {
                Button("Show Help") { NotificationCenter.default.post(name: .showHelp, object: nil) }
                    .keyboardShortcut("?", modifiers: [.command])
                    .accessibilityLabel("Show Help")
                    .accessibilityHint("Open the help documentation")

                Button("Show Onboarding") { NotificationCenter.default.post(name: .showOnboarding, object: nil) }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .accessibilityLabel("Show Onboarding")
                    .accessibilityHint("Show the getting started guide")

                Divider()

                Button("About DevReader") { NotificationCenter.default.post(name: .showAbout, object: nil) }
                    .accessibilityLabel("About DevReader")
                    .accessibilityHint("Show information about DevReader")
            }
        }
        // MARK: - Lifecycle Hooks
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Good place to refresh transient permissions or resume tasks
                break
            case .inactive, .background:
                // Flush any pending debounced persistence
                appEnvironment.pdfController.flushPendingPersistence()
                appEnvironment.libraryStore.flushPendingPersistence()
                appEnvironment.notesStore.flushPendingPersistence()
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
}
