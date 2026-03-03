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

	private static let recentFilesKey = "DevReader.Code.RecentFiles.v1"
	private static let maxRecentFiles = 20

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
		.onAppear { loadRecentFiles() }
	}

	private func loadRecentFiles() {
		guard let paths = UserDefaults.standard.stringArray(forKey: Self.recentFilesKey) else {
			files = []
			return
		}
		files = paths.compactMap { URL(fileURLWithPath: $0) }
			.filter { FileManager.default.fileExists(atPath: $0.path) }
	}

	private static func addToRecentFiles(_ url: URL) {
		var paths = UserDefaults.standard.stringArray(forKey: recentFilesKey) ?? []
		paths.removeAll { $0 == url.path }
		paths.insert(url.path, at: 0)
		if paths.count > maxRecentFiles { paths = Array(paths.prefix(maxRecentFiles)) }
		UserDefaults.standard.set(paths, forKey: recentFilesKey)
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
			let content = try String(contentsOf: url, encoding: .utf8)
			savedCode = content
			currentFileName = url.lastPathComponent

			// Detect language from file extension
			let ext = url.pathExtension.lowercased()
			if let lang = CodeLang.allCases.first(where: { $0.fileExtension == ext }) {
				selectedLanguage = lang
			}

			Self.addToRecentFiles(url)
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
			try FileManager.default.removeItem(at: file)
			loadRecentFiles()
		} catch {
			logError(AppLog.code, "Error deleting file: \(error)")
		}
	}
}
