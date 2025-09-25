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
    
    init() {
        // Initialize enhanced data management
        PersistenceService.initialize()
    }
    
	var body: some Scene {
		WindowGroup {
            ContentView()
                .environment(\.deps, deps)
                .environmentObject(toastCenter)
                .frame(minWidth: 700, minHeight: 600)
		}
		.windowStyle(.titleBar)
		.commands {
			CommandGroup(after: .newItem) {
				Button("New Sketch Page") { NotificationCenter.default.post(name: .newSketchPage, object: nil) }
					.keyboardShortcut("n", modifiers: [.command, .shift])
				Button("Highlight → Note") { NotificationCenter.default.post(name: .captureHighlight, object: nil) }
					.keyboardShortcut("h", modifiers: [.command, .shift])
			}
			CommandGroup(after: .appVisibility) {
				Button("Add Sticky Note") { NotificationCenter.default.post(name: .addStickyNote, object: nil) }
					.keyboardShortcut("s", modifiers: [.command, .shift])
				Button("Close PDF") { NotificationCenter.default.post(name: .closePDF, object: nil) }
					.keyboardShortcut("w", modifiers: [.command])
			}
		}
	}
}
