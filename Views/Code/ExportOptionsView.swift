import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ExportOptionsView: View {
	let code: String
	let language: CodeLang
	let fileName: String
	@Environment(\.dismiss) private var dismiss

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
		let projectName = fileName.components(separatedBy: ".").first ?? "devreader-project"
		let projectPath = url.appendingPathComponent(projectName)

		do {
			try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)

			// Create source file
			let sourceFile = projectPath.appendingPathComponent(fileName)
			try code.write(to: sourceFile, atomically: true, encoding: .utf8)

			// Create VSCode settings
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

			dismiss()
		} catch {
			print("Error creating VSCode project: \(error)")
		}
	}

	private func exportToVim() {
		// Create vim configuration
		let vimConfig = """
		" DevReader Export - \(fileName)
		set syntax=\(getVimSyntax())
		set number
		set autoindent
		set smartindent

		" Code content:
		\(code)
		"""

		saveExportFile(vimConfig, fileExtension: "vim")
	}

	private func exportToEmacs() {
		// Create emacs configuration
		let emacsConfig = """
		;; DevReader Export - \(fileName)
		;; -*- mode: \(getEmacsMode()) -*-

		\(code)
		"""

		saveExportFile(emacsConfig, fileExtension: "el")
	}

	private func exportToJetBrains() {
		// Create IntelliJ project structure
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
		let projectName = fileName.components(separatedBy: ".").first ?? "devreader-project"
		let projectPath = url.appendingPathComponent(projectName)

		do {
			try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)

			// Create source file
			let sourceFile = projectPath.appendingPathComponent(fileName)
			try code.write(to: sourceFile, atomically: true, encoding: .utf8)

			// Create .idea directory with basic project configuration
			let ideaPath = projectPath.appendingPathComponent(".idea")
			try FileManager.default.createDirectory(at: ideaPath, withIntermediateDirectories: true)

			dismiss()
		} catch {
			print("Error creating JetBrains project: \(error)")
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
					print("Error saving file: \(error)")
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
					print("Error saving export file: \(error)")
				}
			}
		}
	}

	private func getVimSyntax() -> String {
		switch language {
		case .python: return "python"
		case .ruby: return "ruby"
		case .node, .javascript: return "javascript"
		case .swift: return "swift"
		case .bash: return "sh"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "cpp"
		case .rust: return "rust"
		case .java: return "java"
		case .typescript: return "typescript"
		case .kotlin: return "kotlin"
		case .dart: return "dart"
		case .sql: return "sql"
		}
	}

	private func getEmacsMode() -> String {
		switch language {
		case .python: return "python"
		case .ruby: return "ruby"
		case .node, .javascript: return "javascript"
		case .swift: return "swift"
		case .bash: return "sh"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "c++"
		case .rust: return "rust"
		case .java: return "java"
		case .typescript: return "typescript"
		case .kotlin: return "kotlin"
		case .dart: return "dart"
		case .sql: return "sql"
		}
	}
}
