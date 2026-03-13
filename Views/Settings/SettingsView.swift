import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@AppStorage("highlightColor") private var highlightColor = "yellow"
	@AppStorage("defaultZoom") private var defaultZoom = 1.0
	@AppStorage("autoSave") private var autoSave = true
	@AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30
	@AppStorage("appAppearance") private var appAppearance: String = "system"
	@AppStorage("pdfDarkMode") private var pdfDarkMode: String = "off"
	@EnvironmentObject private var appEnvironment: AppEnvironment
	private var performanceMonitor: PerformanceMonitor { appEnvironment.performanceMonitor }
	@AppStorage("autoBackupEnabled") private var autoBackupEnabled = false
	@AppStorage("autoBackupIntervalHours") private var autoBackupIntervalHours: Double = 24
	@AppStorage("lastAutoBackupDate") private var lastAutoBackupTimestamp: Double = 0
	@State private var alertMessage = ""
	@State private var alertTitle = ""
	@State private var showingAlert = false

	var body: some View {
		VStack(spacing: 0) {
			// Title bar
			HStack {
				Text("Settings")
					.font(DS.Typography.heading)
				Spacer()
				Button("Done") { dismiss() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.accessibilityIdentifier("settingsDone")
					.accessibilityLabel("Done")
					.accessibilityHint("Close the settings window")
			}
			.padding(.horizontal, DS.Spacing.xl)
			.padding(.vertical, DS.Spacing.md)

			Divider()

			Form {
				Section("Appearance") {
					Picker("Theme", selection: $appAppearance) {
						Text("System").tag("system")
						Text("Light").tag("light")
						Text("Dark").tag("dark")
					}
					.pickerStyle(.segmented)
					.accessibilityIdentifier("themePicker")
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
					.accessibilityIdentifier("highlightColorPicker")
					.accessibilityLabel("Highlight color")
					.accessibilityHint("Select the color used for PDF highlights")
					HStack {
						Text("Default Zoom")
						Spacer()
						Slider(value: $defaultZoom, in: 0.5...2.0, step: 0.1)
							.accessibilityIdentifier("zoomSlider")
							.accessibilityLabel("Default zoom level")
							.accessibilityHint("Adjust the default zoom level for PDFs")
							.accessibilityValue("\(Int(defaultZoom * 100)) percent")
						Text("\(Int(defaultZoom * 100))%").frame(width: 40)
					}
					Picker("PDF Appearance", selection: $pdfDarkMode) {
						ForEach(PDFDarkModeStyle.allCases, id: \.rawValue) { style in
							Text(style.displayName).tag(style.rawValue)
						}
					}
					.pickerStyle(.segmented)
					.accessibilityIdentifier("pdfDarkModePicker")
					.accessibilityLabel("PDF appearance mode")
					.accessibilityHint("Choose how PDFs render: Normal, Dark invert for dark mode, or Sepia tint")
				}
				Section("Data") {
					Toggle("Auto-save Notes", isOn: $autoSave)
					.accessibilityIdentifier("autoSaveToggle")
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
						.accessibilityIdentifier("autosaveIntervalPicker")
						.accessibilityLabel("Autosave interval")
						.accessibilityHint("Choose how often notes are automatically saved")
					}
					Text("Notes and annotations are automatically saved to your Mac.").font(DS.Typography.caption).foregroundStyle(DS.Colors.secondary)
				}
				Section("Performance") {
					HStack {
						Text("Memory Usage")
						Spacer()
						Text(performanceMonitor.formatBytes(performanceMonitor.memoryUsage))
							.font(DS.Typography.caption)
							.foregroundStyle(DS.Colors.secondary)
					}
					HStack {
						Text("Memory Pressure")
						Spacer()
						Text(performanceMonitor.getMemoryPressure())
							.font(DS.Typography.caption)
							.foregroundStyle(performanceMonitor.getMemoryPressure() == "Critical" ? DS.Colors.error :
											performanceMonitor.getMemoryPressure() == "Warning" ? DS.Colors.warning : DS.Colors.success)
					}
					HStack {
						Text("Monitoring")
						Spacer()
						Text(performanceMonitor.isMonitoring ? "Active" : "Inactive")
							.font(DS.Typography.caption)
							.foregroundStyle(performanceMonitor.isMonitoring ? DS.Colors.success : DS.Colors.secondary)
					}
				}

				Section("Large PDF Performance") {
					Text("Large PDF performance monitoring will be available in a future update.")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
					Button("Export Performance Report") {
						exportPerformanceReport()
					}
					.buttonStyle(DSSecondaryButtonStyle())
					.controlSize(.small)
					.accessibilityIdentifier("exportPerformanceReport")
					.accessibilityLabel("Export performance report")
					.accessibilityHint("Export a performance report for large PDF loading")
				}

				Section("Automatic Backups") {
					Toggle("Enable Auto-Backup", isOn: $autoBackupEnabled)
						.accessibilityLabel("Enable automatic backups")
					if autoBackupEnabled {
						Picker("Backup Interval", selection: $autoBackupIntervalHours) {
							Text("Every 6 hours").tag(6.0)
							Text("Every 12 hours").tag(12.0)
							Text("Daily").tag(24.0)
							Text("Weekly").tag(168.0)
						}
						.pickerStyle(.segmented)
						.accessibilityLabel("Backup interval")

						if lastAutoBackupTimestamp > 0 {
							let lastDate = Date(timeIntervalSince1970: lastAutoBackupTimestamp)
							Text("Last backup: \(lastDate.formatted(date: .abbreviated, time: .shortened))")
								.font(DS.Typography.caption)
								.foregroundStyle(DS.Colors.secondary)
						} else {
							Text("No automatic backup yet")
								.font(DS.Typography.caption)
								.foregroundStyle(DS.Colors.secondary)
						}
					}
				}

				Section("Data Management") {
					Text("Data is stored in JSON files for better performance:")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
					Text("\u{2022} Library & Settings: ~/Library/Application Support/DevReader/Data/")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
					Text("\u{2022} Annotated PDFs: ~/Library/Application Support/DevReader/Annotations/")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
					Text("\u{2022} Backups: ~/Library/Application Support/DevReader/Backups/")
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)

					HStack(spacing: DS.Spacing.md) {
						Button("Create Backup") {
							createBackup()
						}
						.buttonStyle(DSSecondaryButtonStyle())
						.controlSize(.small)
						.accessibilityIdentifier("createBackup")
						.accessibilityLabel("Create backup")
						.accessibilityHint("Create a backup of all app data")

						Button("Restore Backup…") {
							restoreBackup()
						}
						.buttonStyle(DSSecondaryButtonStyle())
						.controlSize(.small)
						.accessibilityIdentifier("restoreBackup")
						.accessibilityLabel("Restore backup")
						.accessibilityHint("Restore app data from a previously created backup file")

						Button("Validate Data") {
							validateData()
						}
						.buttonStyle(DSSecondaryButtonStyle())
						.controlSize(.small)
						.accessibilityIdentifier("validateData")
						.accessibilityLabel("Validate data")
						.accessibilityHint("Check all data files for corruption or integrity issues")
					}
					.padding(.top, DS.Spacing.xs)
				}
				Section("Code Execution Sandbox") {
					CodeSandboxSettingsView()
				}

				Section("Keyboard Shortcuts") {
					ShortcutEditorView(store: KeyboardShortcutStore.shared)
				}
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
		appEnvironment.loadingStateManager.startBackup("Creating backup...")

		Task {
			do {
				let backupURL = try PersistenceService.createBackup()
				await MainActor.run {
					alertTitle = "Backup Created"
					alertMessage = "Backup saved to: \(backupURL.lastPathComponent)"
					showingAlert = true
					appEnvironment.loadingStateManager.stopBackup()
				}
			} catch {
				await MainActor.run {
					alertTitle = "Backup Failed"
					alertMessage = "Could not create backup."
					showingAlert = true
					appEnvironment.loadingStateManager.stopBackup()
				}
			}
		}
	}

	private func restoreBackup() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [UTType(filenameExtension: "json") ?? .json]
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.message = "Select a DevReader backup file to restore"
		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			DispatchQueue.main.async {
				appEnvironment.loadingStateManager.startLoading(.general, message: "Restoring backup…")
				Task {
					do {
						try PersistenceService.restoreFromBackup(url)
						await MainActor.run {
							alertTitle = "Backup Restored"
							alertMessage = "Data has been restored. Please restart the app for changes to take full effect."
							showingAlert = true
							appEnvironment.loadingStateManager.stopLoading(.general)
						}
					} catch {
						await MainActor.run {
							alertTitle = "Restore Failed"
							alertMessage = "Could not restore from backup: \(error.localizedDescription)"
							showingAlert = true
							appEnvironment.loadingStateManager.stopLoading(.general)
						}
					}
				}
			}
		}
	}

	private func validateData() {
		appEnvironment.loadingStateManager.startLoading(.general, message: "Validating data integrity...")

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
				appEnvironment.loadingStateManager.stopLoading(.general)
			}
		}
	}

	private func exportPerformanceReport() {
		let monitor = performanceMonitor
		let df = DateFormatter()
		df.dateStyle = .medium
		df.timeStyle = .medium

		let report = """
		DevReader Performance Report
		Generated: \(df.string(from: Date()))
		========================================

		Memory
		  Current Usage:  \(monitor.formatBytes(monitor.memoryUsage))
		  Peak Usage:     \(monitor.formatBytes(monitor.peakMemoryUsage))
		  Average Usage:  \(monitor.formatBytes(monitor.averageMemoryUsage))
		  Pressure:       \(monitor.getMemoryPressure())
		  Monitoring:     \(monitor.isMonitoring ? "Active" : "Inactive")

		Timing
		  Last PDF Load:  \(String(format: "%.2f", monitor.pdfLoadTime))s
		  Last Search:    \(String(format: "%.2f", monitor.searchTime))s
		  Last Annotation:\(String(format: "%.2f", monitor.annotationTime))s

		System
		  Physical Memory:\(monitor.formatBytes(ProcessInfo.processInfo.physicalMemory))
		  Processors:     \(ProcessInfo.processInfo.processorCount)
		  OS Version:     \(ProcessInfo.processInfo.operatingSystemVersionString)
		"""

		let panel = NSSavePanel()
		panel.allowedContentTypes = [.plainText]
		panel.nameFieldStringValue = "DevReader-Performance-Report.txt"
		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			do {
				try report.write(to: url, atomically: true, encoding: .utf8)
				alertTitle = "Report Exported"
				alertMessage = "Performance report saved to \(url.lastPathComponent)"
				showingAlert = true
			} catch {
				alertTitle = "Export Failed"
				alertMessage = "Could not save the performance report."
				showingAlert = true
			}
		}
	}
}
