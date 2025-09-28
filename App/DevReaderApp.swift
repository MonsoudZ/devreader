import SwiftUI
import PDFKit
import Combine

final class AppDependencies: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    // Services are enums with static methods, so we don't need protocols
    // This keeps the dependency injection simple while maintaining testability
    let persistence = PersistenceService.self
    let file = FileService.self
    let annotation = AnnotationService.self
    
    // For testing, we can override these if needed
    init() {
        // Default initialization with actual services
    }
    
    // Convenience initializer for testing (if we need to mock services later)
    static func forTesting() -> AppDependencies {
        return AppDependencies()
    }
}

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies()
}

extension EnvironmentValues {
    var deps: AppDependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}

@main
struct DevReaderApp: App {
    @StateObject private var deps = AppDependencies()
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var appEnvironment = AppEnvironment.shared
    @State private var initializationError: String?
    @State private var showingErrorAlert = false
    
    init() {
        // Initialize enhanced data management with error handling
        do {
            try PersistenceService.initialize()
        } catch {
            // Store error for display after app launches
            UserDefaults.standard.set(error.localizedDescription, forKey: "initializationError")
        }
    }
    
	var body: some Scene {
		WindowGroup {
            ContentView()
                .environment(\.deps, deps)
                .environmentObject(toastCenter)
                .environmentObject(appEnvironment)
                .frame(minWidth: 700, minHeight: 600)
                .onAppear {
                    checkInitializationError()
                }
                .alert("Initialization Error", isPresented: $showingErrorAlert) {
                    Button("OK") { 
                        showingErrorAlert = false
                        clearInitializationError()
                    }
                    Button("Retry") { 
                        retryInitialization()
                    }
                } message: {
                    Text(initializationError ?? "An unknown error occurred during app initialization.")
                }
		}
		.windowStyle(.titleBar)
		.commands {
			// File Menu
			CommandGroup(after: .newItem) {
				Button("Open PDF…") { 
					NotificationCenter.default.post(name: .openPDF, object: nil) 
				}
				.keyboardShortcut("o", modifiers: [.command])
				.accessibilityLabel("Open PDF")
				.accessibilityHint("Open an existing PDF file")
				
				Button("Import PDFs…") { 
					NotificationCenter.default.post(name: .importPDFs, object: nil) 
				}
				.keyboardShortcut("i", modifiers: [.command])
				.accessibilityLabel("Import PDFs")
				.accessibilityHint("Import multiple PDF files into your library")
				
				Divider()
				
				Button("New Sketch Page") { 
					NotificationCenter.default.post(name: .newSketchPage, object: nil) 
				}
				.keyboardShortcut("n", modifiers: [.command, .shift])
				.accessibilityLabel("New Sketch Page")
				.accessibilityHint("Create a new sketch page for the current PDF")
			}
			
			// Edit Menu
			CommandGroup(after: .textEditing) {
				Button("Highlight → Note") { 
					NotificationCenter.default.post(name: .captureHighlight, object: nil) 
				}
				.keyboardShortcut("h", modifiers: [.command, .shift])
				.accessibilityLabel("Capture Highlight to Note")
				.accessibilityHint("Convert selected text to a note")
				
				Button("Add Sticky Note") { 
					NotificationCenter.default.post(name: .addStickyNote, object: nil) 
				}
				.keyboardShortcut("s", modifiers: [.command, .shift])
				.accessibilityLabel("Add Sticky Note")
				.accessibilityHint("Add a sticky note to the current page")
			}
			
			// View Menu
			CommandGroup(after: .appVisibility) {
				Button("Toggle Search") { 
					NotificationCenter.default.post(name: .toggleSearch, object: nil) 
				}
				.keyboardShortcut("f", modifiers: [.command])
				.accessibilityLabel("Toggle Search")
				.accessibilityHint("Show or hide the search panel")
				
				Button("Toggle Library") { 
					NotificationCenter.default.post(name: .toggleLibrary, object: nil) 
				}
				.keyboardShortcut("l", modifiers: [.command])
				.accessibilityLabel("Toggle Library")
				.accessibilityHint("Show or hide the library panel")
				
				Button("Toggle Notes") { 
					NotificationCenter.default.post(name: .toggleNotes, object: nil) 
				}
				.keyboardShortcut("t", modifiers: [.command])
				.accessibilityLabel("Toggle Notes")
				.accessibilityHint("Show or hide the notes panel")
				
				Divider()
				
				Button("Close PDF") { 
					NotificationCenter.default.post(name: .closePDF, object: nil) 
				}
				.keyboardShortcut("w", modifiers: [.command])
				.accessibilityLabel("Close PDF")
				.accessibilityHint("Close the currently open PDF")
			}
			
			// Help Menu
			CommandGroup(after: .help) {
				Button("Show Help") { 
					NotificationCenter.default.post(name: .showHelp, object: nil) 
				}
				.keyboardShortcut("?", modifiers: [.command])
				.accessibilityLabel("Show Help")
				.accessibilityHint("Open the help documentation")
				
				Button("Show Onboarding") { 
					NotificationCenter.default.post(name: .showOnboarding, object: nil) 
				}
				.keyboardShortcut("o", modifiers: [.command, .shift])
				.accessibilityLabel("Show Onboarding")
				.accessibilityHint("Show the getting started guide")
				
				Divider()
				
				Button("About DevReader") { 
					NotificationCenter.default.post(name: .showAbout, object: nil) 
				}
				.accessibilityLabel("About DevReader")
				.accessibilityHint("Show information about DevReader")
			}
		}
	}
	
	// MARK: - Error Handling Methods
	
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
		do {
			try PersistenceService.initialize()
			// Show success toast
			NotificationCenter.default.post(
				name: .showToast,
				object: ToastMessage(
					message: "App initialization successful",
					type: .success
				)
			)
		} catch {
			initializationError = error.localizedDescription
			showingErrorAlert = true
		}
	}
}
