import SwiftUI

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@AppStorage("highlightColor") private var highlightColor = "yellow"
	@AppStorage("defaultZoom") private var defaultZoom = 1.0
	@AppStorage("autoSave") private var autoSave = true
	
	var body: some View {
		NavigationView {
			Form {
				Section("PDF Display") {
					Picker("Highlight Color", selection: $highlightColor) {
						Text("Yellow").tag("yellow")
						Text("Green").tag("green")
						Text("Blue").tag("blue")
						Text("Pink").tag("pink")
					}
					.pickerStyle(.segmented)
					HStack { Text("Default Zoom"); Spacer(); Slider(value: $defaultZoom, in: 0.5...3.0, step: 0.1); Text("\(Int(defaultZoom * 100))%").frame(width: 40) }
				}
				Section("Data") { Toggle("Auto-save Notes", isOn: $autoSave); Text("Notes and annotations are automatically saved to your Mac.").font(.caption).foregroundStyle(.secondary) }
				Section("Keyboard Shortcuts") { VStack(alignment: .leading, spacing: 4) { Text("⌘⇧H - Highlight → Note"); Text("⌘⇧S - Add Sticky Note"); Text("⌘⇧N - New Sketch Page") } .font(.caption).foregroundStyle(.secondary) }
			}
			.navigationTitle("Settings")
			.frame(width: 400, height: 300)
			.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
		}
	}
}
