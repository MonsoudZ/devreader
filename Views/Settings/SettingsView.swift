import SwiftUI
import AppKit
import Foundation

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@AppStorage("highlightColor") private var highlightColor = "yellow"
	@AppStorage("defaultZoom") private var defaultZoom = 1.0
	@AppStorage("autoSave") private var autoSave = true
	@AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30
	@AppStorage("appAppearance") private var appAppearance: String = "system"
	@StateObject private var performanceMonitor = PerformanceMonitor.shared
	@State private var alertMessage = ""
	@State private var alertTitle = ""
	@State private var showingAlert = false

	var body: some View {
		VStack(spacing: 0) {
			// Title bar
			HStack {
				Text("Settings")
					.font(.headline)
				Spacer()
				Button("Done") { dismiss() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.accessibilityLabel("Done")
					.accessibilityHint("Close the settings window")
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 12)

			Divider()

			Form {
				Section("Appearance") {
					Picker("Theme", selection: $appAppearance) {
						Text("System").tag("system")
						Text("Light").tag("light")
						Text("Dark").tag("dark")
					}
					.pickerStyle(.segmented)
					.accessibilityLabel("App theme")
					.accessibilityHint("Choose between system, light, or dark appearance")
				}

				Section("PDF Display") {
					Picker("Highlight Color", selection: $highlightColor) {
						Text("Yellow").tag("yellow")
						Text("Green").tag("green")
						Text("Blue").tag("blue")
						Text("Pink").tag("pink")
					}
					.pickerStyle(.segmented)
					.accessibilityLabel("Highlight color")
					.accessibilityHint("Select the color used for PDF highlights")
					HStack {
						Text("Default Zoom")
						Spacer()
						Slider(value: $defaultZoom, in: 0.5...3.0, step: 0.1)
							.accessibilityLabel("Default zoom level")
							.accessibilityHint("Adjust the default zoom level for PDFs")
							.accessibilityValue("\(Int(defaultZoom * 100)) percent")
						Text("\(Int(defaultZoom * 100))%").frame(width: 40)
					}
				}
				Section("Data") {
					Toggle("Auto-save Notes", isOn: $autoSave)
					.accessibilityLabel("Auto-save notes")
					.accessibilityHint("Automatically save notes at regular intervals")
					HStack {
						Text("Autosave Interval")
						Spacer()
						Picker("Autosave Interval", selection: $autosaveIntervalSeconds) {
							Text("15s").tag(15.0)
							Text("30s").tag(30.0)
							Text("1m").tag(60.0)
							Text("5m").tag(300.0)
						}
						.pickerStyle(.segmented)
						.frame(width: 260)
						.accessibilityLabel("Autosave interval")
						.accessibilityHint("Choose how often notes are automatically saved")
					}
					Text("Notes and annotations are automatically saved to your Mac.").font(.caption).foregroundStyle(.secondary)
				}
				Section("Performance") {
					HStack {
						Text("Memory Usage")
						Spacer()
						Text(performanceMonitor.formatBytes(performanceMonitor.memoryUsage))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					HStack {
						Text("Memory Pressure")
						Spacer()
						Text(performanceMonitor.getMemoryPressure())
							.font(.caption)
							.foregroundStyle(performanceMonitor.getMemoryPressure() == "Critical" ? .red :
											performanceMonitor.getMemoryPressure() == "Warning" ? .orange : .green)
					}
					HStack {
						Text("Monitoring")
						Spacer()
						Text(performanceMonitor.isMonitoring ? "Active" : "Inactive")
							.font(.caption)
							.foregroundStyle(performanceMonitor.isMonitoring ? .green : .secondary)
					}
				}

				Section("Large PDF Performance") {
					Text("Large PDF performance monitoring will be available in a future update.")
						.font(.caption)
						.foregroundStyle(.secondary)
					Button("Export Performance Report") {
						exportPerformanceReport()
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
					.accessibilityLabel("Export performance report")
					.accessibilityHint("Export a performance report for large PDF loading")
				}

				Section("Data Management") {
					Text("Data is stored in JSON files for better performance:")
						.font(.caption)
						.foregroundStyle(.secondary)
					Text("\u{2022} Library & Settings: ~/Library/Application Support/DevReader/Data/")
						.font(.caption)
						.foregroundStyle(.secondary)
					Text("\u{2022} Annotated PDFs: ~/Library/Application Support/DevReader/Annotations/")
						.font(.caption)
						.foregroundStyle(.secondary)
					Text("\u{2022} Backups: ~/Library/Application Support/DevReader/Backups/")
						.font(.caption)
						.foregroundStyle(.secondary)

					HStack(spacing: 12) {
						Button("Create Backup") {
							createBackup()
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
						.accessibilityLabel("Create backup")
						.accessibilityHint("Create a backup of all app data")

						Button("Validate Data") {
							validateData()
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
						.accessibilityLabel("Validate data")
						.accessibilityHint("Check all data files for corruption or integrity issues")
					}
					.padding(.top, 4)
				}
				Section("Keyboard Shortcuts") { VStack(alignment: .leading, spacing: 4) { Text("\u{2318}\u{21e7}H - Highlight \u{2192} Note"); Text("\u{2318}\u{21e7}S - Add Sticky Note"); Text("\u{2318}\u{21e7}N - New Sketch Page") } .font(.caption).foregroundStyle(.secondary) }
			}
			.formStyle(.grouped)
		}
		.alert(alertTitle, isPresented: $showingAlert) {
			Button("OK") { }
		} message: {
			Text(alertMessage)
		}
	}

	private func createBackup() {
		LoadingStateManager.shared.startBackup("Creating backup...")

		Task {
			do {
				let backupURL = try PersistenceService.createBackup()
				await MainActor.run {
					alertTitle = "Backup Created"
					alertMessage = "Backup saved to: \(backupURL.lastPathComponent)"
					showingAlert = true
					LoadingStateManager.shared.stopBackup()
				}
			} catch {
				await MainActor.run {
					alertTitle = "Backup Failed"
					alertMessage = error.localizedDescription
					showingAlert = true
					LoadingStateManager.shared.stopBackup()
				}
			}
		}
	}

	private func validateData() {
		LoadingStateManager.shared.startLoading(.general, message: "Validating data integrity...")

		Task {
			let issues = PersistenceService.validateDataIntegrity()
			await MainActor.run {
				if issues.isEmpty {
					alertTitle = "Data Validation"
					alertMessage = "All data files are valid and intact."
				} else {
					alertTitle = "Data Issues Found"
					alertMessage = issues.joined(separator: "\n")
				}
				showingAlert = true
				LoadingStateManager.shared.stopLoading(.general)
			}
		}
	}

	private func exportPerformanceReport() {
		alertTitle = "Feature Coming Soon"
		alertMessage = "Performance report export will be available in a future update."
		showingAlert = true
	}
}
