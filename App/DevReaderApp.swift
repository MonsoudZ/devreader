import SwiftUI

@main
struct DevReaderApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
				.frame(minWidth: 1200, minHeight: 800)
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
