import SwiftUI
import PDFKit
import Combine

final class AppDependencies: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    let persistence = PersistenceService.self
    let file = FileService.self
    let annotation = AnnotationService.self
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
    
    init() {
        // Initialize enhanced data management
        PersistenceService.initialize()
    }
    
	var body: some Scene {
		WindowGroup {
            ContentView()
                .environment(\.deps, deps)
                .environmentObject(toastCenter)
                .environmentObject(appEnvironment)
                .frame(minWidth: 700, minHeight: 600)
		}
		.windowStyle(.titleBar)
		.commands {
			CommandGroup(after: .newItem) {
				Button("Open PDF") { NotificationCenter.default.post(name: .openPDF, object: nil) }
					.keyboardShortcut("o", modifiers: [.command])
				Button("Import PDFs") { NotificationCenter.default.post(name: .importPDFs, object: nil) }
					.keyboardShortcut("i", modifiers: [.command])
				Button("New Sketch Page") { NotificationCenter.default.post(name: .newSketchPage, object: nil) }
					.keyboardShortcut("n", modifiers: [.command, .shift])
			}
			CommandGroup(after: .appVisibility) {
				Button("Highlight → Note") { NotificationCenter.default.post(name: .captureHighlight, object: nil) }
					.keyboardShortcut("h", modifiers: [.command, .shift])
				Button("Add Sticky Note") { NotificationCenter.default.post(name: .addStickyNote, object: nil) }
					.keyboardShortcut("s", modifiers: [.command, .shift])
				Button("Toggle Search") { NotificationCenter.default.post(name: .toggleSearch, object: nil) }
					.keyboardShortcut("f", modifiers: [.command])
				Button("Close PDF") { NotificationCenter.default.post(name: .closePDF, object: nil) }
					.keyboardShortcut("w", modifiers: [.command])
				Button("Show Help") { NotificationCenter.default.post(name: .showHelp, object: nil) }
					.keyboardShortcut("?", modifiers: [.command])
			}
		}
	}
}
