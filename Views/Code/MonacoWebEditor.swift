import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MonacoWebEditor: View {
	@Environment(\.colorScheme) private var colorScheme
	@AppStorage("monacoCode") private var savedCode: String = ""
	@State private var useFallback = false
	@State private var isMonacoLoaded = false
	@State private var loadTimeoutTask: Task<Void, Never>?
	@State private var selectedLanguage: CodeLang = .python
	@State private var output: String = ""
	@State private var isRunning = false
	@State private var showFileManager = false
	@State private var currentFileName = "untitled"
	@State private var showExportOptions = false

	private func html(_ initial: String) -> String {
		let language = selectedLanguage.monacoLanguage
		return """
		<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
		<style>html,body,#container{height:100%;margin:0}#container{display:flex;flex-direction:column}#editor{flex:1;}</style>
		<script src=\"https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js\"></script>
		<script>
		require.config({ paths: { 'vs': 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs' } });
		window._code = `\(initial.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`").replacingOccurrences(of: "$", with: "\\$"))`;
		window._language = '\(language)';
		require(['vs/editor/editor.main'], function(){
		  window.editor = monaco.editor.create(document.getElementById('editor'), {
		    value: window._code,
		    language: window._language,
		    automaticLayout: true,
		    theme: '\(colorScheme == .dark ? "vs-dark" : "vs")',
		    minimap: { enabled: true },
		    wordWrap: 'on',
		    lineNumbers: 'on',
		    folding: true,
		    bracketPairColorization: { enabled: true },
		    formatOnPaste: true,
		    formatOnType: true
		  });
		  window.editor.onDidChangeModelContent(function(){
		    try { window.webkit.messageHandlers.codeChanged.postMessage(window.editor.getValue()); } catch(e) { }
		  });
		  try { window.webkit.messageHandlers.editorReady.postMessage('ready'); } catch(e) { }
		});
		</script>
		</head><body><div id=\"container\"><div id=\"editor\"></div></div></body></html>
		"""
	}

	var body: some View {
		VStack(spacing: 0) {
			// Toolbar
			HStack {
				Picker("Language", selection: $selectedLanguage) {
					ForEach(CodeLang.allCases, id: \.self) { lang in
						Text(lang.rawValue).tag(lang)
					}
				}
				.pickerStyle(.menu)
				.frame(maxWidth: 120)
				.accessibilityIdentifier("monacoLanguagePicker")
				.accessibilityLabel("Programming language")
				.accessibilityHint("Select the programming language for the editor")

				Button("Run") { executeCode() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.disabled(isRunning)
					.accessibilityIdentifier("monacoRunButton")
					.accessibilityLabel("Run code")
					.accessibilityHint("Execute the code in the editor")

				Button {
					saveFile()
				} label: {
					Label("Save", systemImage: "square.and.arrow.down")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("monacoSaveButton")
				.accessibilityLabel("Save file")
				.accessibilityHint("Save the current code to a file")

				Button {
					showFileManager = true
				} label: {
					Label("Load", systemImage: "folder")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("monacoLoadButton")
				.accessibilityLabel("Load file")
				.accessibilityHint("Open the file manager to load a file")

				Button {
					showExportOptions = true
				} label: {
					Label("Export", systemImage: "square.and.arrow.up")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("monacoExportButton")
				.accessibilityLabel("Export code")
				.accessibilityHint("Export code to various editor formats")

				Spacer()

				Text(currentFileName)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding(8)
			.background(Color(NSColor.controlBackgroundColor))

			Divider()

			// Editor and Output
			HStack(spacing: 0) {
				// Editor
				VStack(spacing: 0) {
					if useFallback {
						FallbackCodeEditor(code: $savedCode, onRetryMonaco: {
							useFallback = false
							isMonacoLoaded = false
						})
					} else {
						WebViewHTML(html: html(savedCode), savedCode: savedCode, language: selectedLanguage.monacoLanguage, theme: colorScheme == .dark ? "vs-dark" : "vs", onCodeChange: { newCode in
							savedCode = newCode
						}, onEditorReady: {
							isMonacoLoaded = true
							loadTimeoutTask?.cancel()
							LoadingStateManager.shared.stopMonacoLoading()
						})
						.onAppear {
							LoadingStateManager.shared.startMonacoLoading("Initializing Monaco editor...")
							loadTimeoutTask?.cancel()
							loadTimeoutTask = Task { @MainActor in
								try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
								guard !Task.isCancelled, !isMonacoLoaded else { return }
								useFallback = true
								LoadingStateManager.shared.stopMonacoLoading()
							}
						}
						.onDisappear {
							loadTimeoutTask?.cancel()
						}
					}
				}
				.frame(maxWidth: .infinity)

				// Output Panel
				VStack(alignment: .leading, spacing: 0) {
					HStack {
						Text("Output")
							.font(.headline)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
						Spacer()
						Button("Clear") { output = "" }
							.font(.caption)
							.padding(.horizontal, 8)
							.accessibilityIdentifier("monacoClearOutput")
							.accessibilityLabel("Clear output")
							.accessibilityHint("Clear the code execution output")
					}
					.background(Color(NSColor.controlBackgroundColor))

					ScrollView {
						Text(output)
							.font(.system(.footnote, design: .monospaced))
							.padding(8)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					.background(Color(NSColor.textBackgroundColor))
				}
				.frame(width: 300)
			}
		}
		.sheet(isPresented: $showFileManager) {
			FileManagerView(
				selectedLanguage: $selectedLanguage,
				savedCode: $savedCode,
				currentFileName: $currentFileName
			)
		}
		.sheet(isPresented: $showExportOptions) {
			ExportOptionsView(
				code: savedCode,
				language: selectedLanguage,
				fileName: currentFileName
			)
		}

	}

	// MARK: - Helper Functions

	private 	func executeCode() {
		isRunning = true
		output = ""
		LoadingStateManager.shared.startLoading(.general, message: "Running \(selectedLanguage.rawValue) code...")

		DispatchQueue.global(qos: .userInitiated).async {
			let result = Shell.runCode(selectedLanguage.rawValue, code: savedCode)
			DispatchQueue.main.async {
				self.output = result
				self.isRunning = false
				LoadingStateManager.shared.stopLoading(.general)
			}
		}
	}

	private func saveFile() {
		LoadingStateManager.shared.startFileOperation("Saving file...")

		let panel = NSSavePanel()
		panel.allowedContentTypes = [UTType(filenameExtension: selectedLanguage.fileExtension) ?? .plainText]
		panel.nameFieldStringValue = currentFileName

		panel.begin { response in
			if response == .OK, let url = panel.url {
				do {
					try savedCode.write(to: url, atomically: true, encoding: .utf8)
					currentFileName = url.lastPathComponent
					LoadingStateManager.shared.stopFileOperation()
				} catch {
					output = "Error saving file: \(error.localizedDescription)"
					LoadingStateManager.shared.stopFileOperation()
				}
			} else {
				LoadingStateManager.shared.stopFileOperation()
			}
		}
	}
}

// MARK: - Fallback Code Editor

struct FallbackCodeEditor: View {
	@Binding var code: String
	var onRetryMonaco: (() -> Void)?
	var body: some View {
		VStack {
			HStack {
				Text("Monaco Editor Unavailable — Using Fallback")
					.font(.caption)
					.foregroundColor(.secondary)
				Spacer()
				if let retry = onRetryMonaco {
					Button("Retry Monaco") { retry() }
						.font(.caption)
						.accessibilityIdentifier("retryMonaco")
						.accessibilityLabel("Retry Monaco editor")
						.accessibilityHint("Attempt to reload the Monaco editor")
				}
			}
			.padding(.horizontal, 8)
			.padding(.top, 4)
			TextEditor(text: $code)
				.font(.system(.body, design: .monospaced))
				.padding(8)
		}
	}
}
