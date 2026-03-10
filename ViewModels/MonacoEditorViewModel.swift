import Foundation
import Combine
import UniformTypeIdentifiers
import AppKit

@MainActor
final class MonacoEditorViewModel: ObservableObject {
	@Published var useFallback = false
	@Published var isMonacoLoaded = false
	@Published var selectedLanguage: CodeLang = .python
	@Published var output: String = ""
	@Published var isRunning = false
	@Published var showFileManager = false
	@Published var currentFileName = "untitled"
	@Published var showExportOptions = false

	private let loadingStateManager: LoadingStateManager
	private var loadTimeoutTask: Task<Void, Never>?

	init(loadingStateManager: LoadingStateManager = .shared) {
		self.loadingStateManager = loadingStateManager
	}

	deinit {
		loadTimeoutTask?.cancel()
	}

	// MARK: - Monaco Loading

	func startMonacoLoadTimeout() {
		loadingStateManager.startMonacoLoading("Initializing Monaco editor...")
		loadTimeoutTask?.cancel()
		loadTimeoutTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
			guard !Task.isCancelled, !isMonacoLoaded else { return }
			useFallback = true
			loadingStateManager.stopMonacoLoading()
		}
	}

	func cancelMonacoLoadTimeout() {
		loadTimeoutTask?.cancel()
	}

	func onEditorReady() {
		isMonacoLoaded = true
		loadTimeoutTask?.cancel()
		loadingStateManager.stopMonacoLoading()
	}

	func retryMonaco() {
		useFallback = false
		isMonacoLoaded = false
	}

	// MARK: - Code Execution

	func executeCode(source: String) {
		isRunning = true
		output = ""
		loadingStateManager.startLoading(.general, message: "Running \(selectedLanguage.rawValue) code...")
		let lang = selectedLanguage.rawValue
		let lsm = loadingStateManager
		Task.detached(priority: .userInitiated) {
			let result = Shell.runCode(lang, code: source)
			await MainActor.run {
				self.output = result
				self.isRunning = false
				lsm.stopLoading(.general)
			}
		}
	}

	// MARK: - File Save

	func saveFile(code: String) {
		loadingStateManager.startFileOperation("Saving file...")

		let panel = NSSavePanel()
		panel.allowedContentTypes = [UTType(filenameExtension: selectedLanguage.fileExtension) ?? .plainText]
		panel.nameFieldStringValue = currentFileName

		panel.begin { [weak self] response in
			guard let self else { return }
			if response == .OK, let url = panel.url {
				do {
					try code.write(to: url, atomically: true, encoding: .utf8)
					self.currentFileName = url.lastPathComponent
					self.loadingStateManager.stopFileOperation()
				} catch {
					self.output = "Could not save file."
					self.loadingStateManager.stopFileOperation()
				}
			} else {
				self.loadingStateManager.stopFileOperation()
			}
		}
	}
}
