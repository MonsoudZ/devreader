import SwiftUI
import UniformTypeIdentifiers
import AppKit
import os.log

struct ExportOptionsView: View {
	let code: String
	let language: CodeLang
	let fileName: String
	@Environment(\.dismiss) private var dismiss

	@State private var errorMessage: String?

	var body: some View {
		VStack(spacing: 20) {
			Text("Export Code")
				.font(.headline)

			VStack(alignment: .leading, spacing: 15) {
				Button("Export to VSCode Project") { exportToVSCode() }
					.accessibilityIdentifier("exportToVSCode")
					.accessibilityLabel("Export to VSCode")
					.accessibilityHint("Create a VSCode project with the current code")
				Button("Export to Vim Configuration") { exportToVim() }
					.accessibilityIdentifier("exportToVim")
					.accessibilityLabel("Export to Vim")
					.accessibilityHint("Export code as a Vim configuration file")
				Button("Export to Emacs Configuration") { exportToEmacs() }
					.accessibilityIdentifier("exportToEmacs")
					.accessibilityLabel("Export to Emacs")
					.accessibilityHint("Export code as an Emacs configuration file")
				Button("Export to JetBrains Project") { exportToJetBrains() }
					.accessibilityIdentifier("exportToJetBrains")
					.accessibilityLabel("Export to JetBrains")
					.accessibilityHint("Create a JetBrains project with the current code")
				Button("Export as Standalone File") { exportAsFile() }
					.accessibilityIdentifier("exportAsFile")
					.accessibilityLabel("Export as standalone file")
					.accessibilityHint("Save the code as a standalone source file")
			}

			HStack {
				Button("Cancel") { dismiss() }
					.accessibilityIdentifier("exportCancel")
					.accessibilityLabel("Cancel export")
					.accessibilityHint("Close the export options without exporting")
				Spacer()
			}
		}
		.padding()
		.frame(width: 400, height: 300)
		.alert("Export Failed", isPresented: Binding(
			get: { errorMessage != nil },
			set: { if !$0 { errorMessage = nil } }
		)) {
			Button("OK") { errorMessage = nil }
		} message: {
			Text(errorMessage ?? "An unknown error occurred.")
		}
	}

	private func exportToVSCode() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.prompt = "Select VSCode Project Folder"

		panel.begin { response in
			if response == .OK, let url = panel.url {
				createVSCodeProject(at: url)
			}
		}
	}

	private func createVSCodeProject(at url: URL) {
		createProjectWithSource(at: url) { projectPath in
			let settingsPath = projectPath.appendingPathComponent(".vscode")
			try FileManager.default.createDirectory(at: settingsPath, withIntermediateDirectories: true)

			let settings = """
			{
				"files.associations": {
					"*.\(language.fileExtension)": "\(language.monacoLanguage)"
				}
			}
			"""
			try settings.write(to: settingsPath.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
		}
	}

	private func exportToVim() {
		let commentPrefix = language.lineCommentPrefix
		let content = """
		\(commentPrefix) vim: set ft=\(language.vimSyntax):
		\(commentPrefix) Exported from DevReader - \(fileName)

		\(code)
		"""
		saveExportFile(content, fileExtension: language.fileExtension)
	}

	private func exportToEmacs() {
		let commentPrefix = language.lineCommentPrefix
		let content = """
		\(commentPrefix) -*- mode: \(language.emacsMode) -*-
		\(commentPrefix) Exported from DevReader - \(fileName)

		\(code)
		"""
		saveExportFile(content, fileExtension: language.fileExtension)
	}

	private func exportToJetBrains() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.prompt = "Select JetBrains Project Folder"

		panel.begin { response in
			if response == .OK, let url = panel.url {
				createJetBrainsProject(at: url)
			}
		}
	}

	private func createJetBrainsProject(at url: URL) {
		createProjectWithSource(at: url) { projectPath in
			let ideaPath = projectPath.appendingPathComponent(".idea")
			try FileManager.default.createDirectory(at: ideaPath, withIntermediateDirectories: true)
		}
	}

	/// Shared project creation: makes project dir, writes source file, runs extra setup, dismisses.
	private func createProjectWithSource(at url: URL, extraSetup: (URL) throws -> Void = { _ in }) {
		let projectName = fileName.components(separatedBy: ".").first ?? "devreader-project"
		let projectPath = url.appendingPathComponent(projectName)
		let sourceFile = projectPath.appendingPathComponent(fileName)

		if FileManager.default.fileExists(atPath: sourceFile.path) {
			guard confirmOverwrite(sourceFile) else { return }
		}

		do {
			try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)
			try code.write(to: sourceFile, atomically: true, encoding: .utf8)
			try extraSetup(projectPath)
			dismiss()
		} catch {
			logError(AppLog.code, "Error creating project: \(error)")
			errorMessage = "Could not create project."
		}
	}

	private func exportAsFile() {
		let panel = NSSavePanel()
		panel.allowedContentTypes = [UTType(filenameExtension: language.fileExtension) ?? .plainText]
		panel.nameFieldStringValue = fileName

		panel.begin { response in
			if response == .OK, let url = panel.url {
				do {
					try code.write(to: url, atomically: true, encoding: .utf8)
					dismiss()
				} catch {
					logError(AppLog.code, "Error saving file: \(error)")
					errorMessage = "Could not save file."
				}
			}
		}
	}

	private func saveExportFile(_ content: String, fileExtension: String) {
		let panel = NSSavePanel()
		panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .plainText]
		panel.nameFieldStringValue = "\(fileName).\(fileExtension)"

		panel.begin { response in
			if response == .OK, let url = panel.url {
				do {
					try content.write(to: url, atomically: true, encoding: .utf8)
					dismiss()
				} catch {
					logError(AppLog.code, "Error saving export file: \(error)")
					errorMessage = "Could not save export file."
				}
			}
		}
	}

	private func confirmOverwrite(_ file: URL) -> Bool {
		let alert = NSAlert()
		alert.messageText = "File Already Exists"
		alert.informativeText = "\"\(file.lastPathComponent)\" already exists at this location. Do you want to replace it?"
		alert.alertStyle = .warning
		alert.addButton(withTitle: "Replace")
		alert.addButton(withTitle: "Cancel")
		return alert.runModal() == .alertFirstButtonReturn
	}
}
