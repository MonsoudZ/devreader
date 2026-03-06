import SwiftUI

struct CodeSandboxSettingsView: View {
	@AppStorage("codeExecTimeout") private var timeout: Double = 30
	@AppStorage("codeExecMemoryMB") private var memoryMB: Int = 512
	@AppStorage("codeExecFileSizeMB") private var fileSizeMB: Int = 10

	var body: some View {
		Text("Resource limits applied when running code snippets.")
			.font(.caption)
			.foregroundStyle(.secondary)

		HStack {
			Text("Timeout")
			Spacer()
			Picker("Timeout", selection: $timeout) {
				Text("10s").tag(10.0)
				Text("30s").tag(30.0)
				Text("60s").tag(60.0)
				Text("120s").tag(120.0)
			}
			.pickerStyle(.segmented)
			.frame(width: 260)
			.accessibilityIdentifier("sandboxTimeout")
			.accessibilityLabel("Execution timeout")
			.accessibilityHint("Maximum time a code snippet can run before being terminated")
		}

		HStack {
			Text("Memory Limit")
			Spacer()
			Picker("Memory", selection: $memoryMB) {
				Text("256 MB").tag(256)
				Text("512 MB").tag(512)
				Text("1 GB").tag(1024)
				Text("2 GB").tag(2048)
			}
			.pickerStyle(.segmented)
			.frame(width: 260)
			.accessibilityIdentifier("sandboxMemory")
			.accessibilityLabel("Memory limit")
			.accessibilityHint("Maximum virtual memory for code execution")
		}

		HStack {
			Text("File Size Limit")
			Spacer()
			Picker("File Size", selection: $fileSizeMB) {
				Text("5 MB").tag(5)
				Text("10 MB").tag(10)
				Text("50 MB").tag(50)
				Text("100 MB").tag(100)
			}
			.pickerStyle(.segmented)
			.frame(width: 260)
			.accessibilityIdentifier("sandboxFileSize")
			.accessibilityLabel("File size limit")
			.accessibilityHint("Maximum output file size for code execution")
		}

		HStack {
			Button("Reset to Defaults") {
				timeout = 30
				memoryMB = 512
				fileSizeMB = 10
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.accessibilityIdentifier("sandboxResetDefaults")

			Spacer()

			Text("Timeout: \(Int(timeout))s | Memory: \(memoryMB) MB | Files: \(fileSizeMB) MB")
				.font(.caption2)
				.foregroundStyle(.tertiary)
		}
	}
}
