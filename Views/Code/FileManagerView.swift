import SwiftUI
import AppKit
import os.log

struct FileManagerView: View {
	@Binding var selectedLanguage: CodeLang
	@Binding var savedCode: String
	@Binding var currentFileName: String
	@Environment(\.dismiss) private var dismiss

	@State private var files: [URL] = []
	@State private var selectedFile: URL?

	var body: some View {
		VStack {
			HStack {
				Text("File Manager")
					.font(.headline)
				Spacer()
				Button("Close") { dismiss() }
					.accessibilityIdentifier("fileManagerClose")
					.accessibilityLabel("Close file manager")
					.accessibilityHint("Close the file manager window")
			}
			.padding()

			HStack {
				// File List
				VStack(alignment: .leading) {
					Text("Recent Files")
						.font(.subheadline)
						.foregroundColor(.secondary)

					List(files, id: \.self, selection: $selectedFile) { file in
						HStack {
							Image(systemName: "doc.text")
							Text(file.lastPathComponent)
						}
						.onTapGesture {
							loadFile(file)
						}
					}
				}
				.frame(width: 200)

				Divider()

				// File Actions
				VStack {
					Button("Open File...") { openFile() }
						.accessibilityIdentifier("fileManagerOpen")
						.accessibilityLabel("Open file")
						.accessibilityHint("Browse and open a file from disk")
					Button("New File") { newFile() }
						.accessibilityIdentifier("fileManagerNew")
						.accessibilityLabel("New file")
						.accessibilityHint("Create a new empty file")
					Button("Delete Selected") { deleteFile() }
						.disabled(selectedFile == nil)
						.accessibilityIdentifier("fileManagerDelete")
						.accessibilityLabel("Delete selected file")
						.accessibilityHint("Delete the currently selected file")
				}
				.padding()
			}
		}
		.frame(width: 500, height: 400)
		.onAppear { files = CodeFileService.loadRecentFiles() }
	}

	private func openFile() {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.canChooseFiles = true

		panel.begin { response in
			if response == .OK, let url = panel.url {
				loadFile(url)
			}
		}
	}

	private func loadFile(_ url: URL) {
		do {
			let content = try CodeFileService.loadFile(at: url)
			savedCode = content
			currentFileName = url.lastPathComponent

			if let lang = CodeFileService.detectLanguage(for: url) {
				selectedLanguage = lang
			}

			CodeFileService.addToRecentFiles(url)
			dismiss()
		} catch {
			logError(AppLog.code, "Error loading file: \(error)")
		}
	}

	private func newFile() {
		savedCode = ""
		currentFileName = "untitled.\(selectedLanguage.fileExtension)"
		dismiss()
	}

	private func deleteFile() {
		guard let file = selectedFile else { return }

		do {
			try CodeFileService.deleteFileWithConfirmation(file)
			files = CodeFileService.loadRecentFiles()
		} catch {
			logError(AppLog.code, "Error deleting file: \(error)")
		}
	}
}
