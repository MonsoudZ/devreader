import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MonacoWebEditor: View {
	@Environment(\.colorScheme) private var colorScheme
	@AppStorage("monacoCode") private var savedCode: String = ""
	@StateObject private var vm = MonacoEditorViewModel()

	// Monaco version pinning — single source of truth for CDN URL and integrity hash.
	// To upgrade: update monacoVersion, regenerate the SRI hash for the new loader.js,
	// and update monacoLoaderSRI. Verify at: https://www.srihash.org/
	static let monacoVersion = "0.52.0"
	static let monacoBaseURL = "https://cdn.jsdelivr.net/npm/monaco-editor@\(monacoVersion)/min/vs"
	static let monacoLoaderSRI = "sha384-tSPY4oVmbJKVAvy9W7NTVMqSrS/gYyJLECoFWtQ10h4qIDQTg1h3DSfF0eV2Bbbz"

	private func html(_ initial: String) -> String {
		let language = vm.selectedLanguage.monacoLanguage
		let baseURL = Self.monacoBaseURL
		let sri = Self.monacoLoaderSRI
		return """
		<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
		<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src https://cdn.jsdelivr.net/npm/monaco-editor@\(Self.monacoVersion)/ 'unsafe-eval'; style-src https://cdn.jsdelivr.net/npm/monaco-editor@\(Self.monacoVersion)/ 'unsafe-inline'; font-src https://cdn.jsdelivr.net/npm/monaco-editor@\(Self.monacoVersion)/; worker-src blob:; connect-src 'self';\">
		<style>html,body,#container{height:100%;margin:0}#container{display:flex;flex-direction:column}#editor{flex:1;}</style>
		<script src=\"\(baseURL)/loader.js\" integrity=\"\(sri)\" crossorigin=\"anonymous\"></script>
		<script>
		require.config({ paths: { 'vs': '\(baseURL)' } });
		window._code = `\(initial.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`").replacingOccurrences(of: "$", with: "\\$").replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029"))`;
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
				Picker("Language", selection: $vm.selectedLanguage) {
					ForEach(CodeLang.allCases, id: \.self) { lang in
						Text(lang.rawValue).tag(lang)
					}
				}
				.pickerStyle(.menu)
				.frame(maxWidth: 120)
				.accessibilityIdentifier("monacoLanguagePicker")
				.accessibilityLabel("Programming language")
				.accessibilityHint("Select the programming language for the editor")

				Button("Run") { vm.executeCode(source: savedCode) }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.disabled(vm.isRunning)
					.accessibilityIdentifier("monacoRunButton")
					.accessibilityLabel("Run code")
					.accessibilityHint("Execute the code in the editor")

				Button {
					vm.saveFile(code: savedCode)
				} label: {
					Label("Save", systemImage: "square.and.arrow.down")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("monacoSaveButton")
				.accessibilityLabel("Save file")
				.accessibilityHint("Save the current code to a file")

				Button {
					vm.showFileManager = true
				} label: {
					Label("Load", systemImage: "folder")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("monacoLoadButton")
				.accessibilityLabel("Load file")
				.accessibilityHint("Open the file manager to load a file")

				Button {
					vm.showExportOptions = true
				} label: {
					Label("Export", systemImage: "square.and.arrow.up")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("monacoExportButton")
				.accessibilityLabel("Export code")
				.accessibilityHint("Export code to various editor formats")

				Spacer()

				Text(vm.currentFileName)
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
					if vm.useFallback {
						FallbackCodeEditor(code: $savedCode, onRetryMonaco: {
							vm.retryMonaco()
						})
					} else {
						WebViewHTML(html: html(savedCode), savedCode: savedCode, language: vm.selectedLanguage.monacoLanguage, theme: colorScheme == .dark ? "vs-dark" : "vs", onCodeChange: { newCode in
							savedCode = newCode
						}, onEditorReady: {
							vm.onEditorReady()
						})
						.onAppear {
							vm.startMonacoLoadTimeout()
						}
						.onDisappear {
							vm.cancelMonacoLoadTimeout()
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
						Button("Clear") { vm.output = "" }
							.font(.caption)
							.padding(.horizontal, 8)
							.accessibilityIdentifier("monacoClearOutput")
							.accessibilityLabel("Clear output")
							.accessibilityHint("Clear the code execution output")
					}
					.background(Color(NSColor.controlBackgroundColor))

					ScrollView {
						Text(vm.output)
							.font(.system(.footnote, design: .monospaced))
							.padding(8)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					.background(Color(NSColor.textBackgroundColor))
				}
				.frame(width: 300)
			}
		}
		.sheet(isPresented: $vm.showFileManager) {
			FileManagerView(
				selectedLanguage: $vm.selectedLanguage,
				savedCode: $savedCode,
				currentFileName: $vm.currentFileName
			)
		}
		.sheet(isPresented: $vm.showExportOptions) {
			ExportOptionsView(
				code: savedCode,
				language: vm.selectedLanguage,
				fileName: vm.currentFileName
			)
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
