import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct CodePane: View {
	@State private var mode: CodeMode = .scratch
	var body: some View {
		VStack(spacing: 0) {
			Picker("", selection: $mode) {
				Text("Scratchpad").tag(CodeMode.scratch)
				Text("Monaco").tag(CodeMode.monaco)
			}
			.pickerStyle(.segmented)
			.padding(8)
			Divider()
			switch mode {
			case .scratch: ScratchRunner()
			case .monaco: MonacoWebEditor()
			}
		}
	}
}

enum CodeMode { case scratch, monaco }

struct ScratchRunner: View {
	@State private var language: CodeLang = .python
	@State private var code: String = ""
	@State private var output: String = ""
	@State private var isRunning = false
	
	private var defaultCode: String {
		switch language {
		case .python:
			return "# Write some quick test code and run it.\n# Example:\n# print('hello from DevReader!')"
		case .ruby:
			return "# Write some quick test code and run it.\n# Example:\n# puts 'hello from DevReader!'"
		case .node, .javascript:
			return "// Write some quick test code and run it.\n// Example:\n// console.log('hello from DevReader!');"
		case .swift:
			return "// Write some quick test code and run it.\n// Example:\n// print(\"hello from DevReader!\")"
		case .bash:
			return "# Write some quick test code and run it.\n# Example:\n# echo 'hello from DevReader!'"
		case .go:
			return "// Write some quick test code and run it.\n// Example:\n// package main\n// import \"fmt\"\n// func main() { fmt.Println(\"hello from DevReader!\") }"
		case .c:
			return "// Write some quick test code and run it.\n// Example:\n// #include <stdio.h>\n// int main() { printf(\"hello from DevReader!\\n\"); return 0; }"
		case .cpp:
			return "// Write some quick test code and run it.\n// Example:\n// #include <iostream>\n// int main() { std::cout << \"hello from DevReader!\" << std::endl; return 0; }"
		case .rust:
			return "// Write some quick test code and run it.\n// Example:\n// fn main() { println!(\"hello from DevReader!\"); }"
		case .java:
			return "// Write some quick test code and run it.\n// Example:\n// public class Main {\n//     public static void main(String[] args) {\n//         System.out.println(\"hello from DevReader!\");\n//     }\n// }"
		case .sql:
			return "-- Write some quick test code and run it.\n-- Example:\n-- SELECT 'hello from DevReader!' as message;"
		}
	}
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Picker("Language", selection: $language) {
					ForEach(CodeLang.allCases, id: \.self) { lang in
						Text(lang.rawValue).tag(lang)
					}
				}
				.pickerStyle(.menu)
				.frame(maxWidth: 150)
				
				Spacer()
				Button(isRunning ? "Running…" : "Run") { run() }.disabled(isRunning)
			}.padding(8)
			Divider()
			TextEditor(text: $code)
				.font(.system(.body, design: .monospaced))
				.padding(8)
			Divider()
			ScrollView { Text(output).font(.system(.footnote, design: .monospaced)).padding(8) }
		}
		.onAppear {
			if code.isEmpty {
				code = defaultCode
			}
		}
		.onChange(of: language) {
			code = defaultCode
		}
	}
	
	func run() {
		isRunning = true; output = ""
		LoadingStateManager.shared.startLoading(.general, message: "Running \(language.rawValue) code...")
		DispatchQueue.global(qos: .userInitiated).async {
			let result = Shell.runCode(language.rawValue, code: code)
			DispatchQueue.main.async { 
				self.output = result; 
				self.isRunning = false
				LoadingStateManager.shared.stopLoading(.general)
			}
		}
	}
}

enum CodeLang: String, CaseIterable {
	case python = "Python"
	case ruby = "Ruby"
	case node = "Node.js"
	case swift = "Swift"
	case javascript = "JavaScript"
	case bash = "Bash"
	case go = "Go"
	case c = "C"
	case cpp = "C++"
	case rust = "Rust"
	case java = "Java"
	case sql = "SQL"
	
	var command: String {
		switch self {
		case .python: return "python3"
		case .ruby: return "ruby"
		case .node: return "node"
		case .swift: return "swift"
		case .javascript: return "node"
		case .bash: return "bash"
		case .go: return "go"
		case .c: return "gcc"
		case .cpp: return "g++"
		case .rust: return "rustc"
		case .java: return "javac"
		case .sql: return "sqlite3"
		}
	}
	
	var args: [String] {
		switch self {
		case .python: return ["-c"]
		case .ruby: return ["-e"]
		case .node: return ["-e"]
		case .swift: return ["-"]
		case .javascript: return ["-e"]
		case .bash: return ["-c"]
		case .go: return ["run", "-"]
		case .c: return ["-o", "temp_c", "-"]
		case .cpp: return ["-o", "temp_cpp", "-"]
		case .rust: return ["-o", "temp_rust", "-"]
		case .java: return ["-"]
		case .sql: return ["-"]
		}
	}
	
	var fileExtension: String {
		switch self {
		case .python: return "py"
		case .ruby: return "rb"
		case .node: return "js"
		case .swift: return "swift"
		case .javascript: return "js"
		case .bash: return "sh"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "cpp"
		case .rust: return "rs"
		case .java: return "java"
		case .sql: return "sql"
		}
	}
}

struct MonacoWebEditor: View {
	@AppStorage("monacoCode") private var savedCode: String = ""
	@State private var useFallback = false
	@State private var selectedLanguage: CodeLang = .python
	@State private var output: String = ""
	@State private var isRunning = false
	@State private var showFileManager = false
	@State private var currentFileName = "untitled"
	@State private var showExportOptions = false
	
	private func html(_ initial: String) -> String {
		let language = getMonacoLanguage(selectedLanguage)
		return """
		<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
		<style>html,body,#container{height:100%;margin:0}#container{display:flex;flex-direction:column}#editor{flex:1;}</style>
		<script src=\"https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js\"></script>
		<script>
		require.config({ paths: { 'vs': 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs' } });
		window._code = `\(initial.replacingOccurrences(of: "`", with: "\\`"))`;
		window._language = '\(language)';
		require(['vs/editor/editor.main'], function(){
		  window.editor = monaco.editor.create(document.getElementById('editor'), { 
		    value: window._code, 
		    language: window._language, 
		    automaticLayout: true,
		    theme: 'vs-dark',
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
		});
		</script>
		</head><body><div id=\"container\"><div id=\"editor\"></div></div></body></html>
		"""
	}
	
	private func getMonacoLanguage(_ lang: CodeLang) -> String {
		switch lang {
		case .python: return "python"
		case .ruby: return "ruby"
		case .node, .javascript: return "javascript"
		case .swift: return "swift"
		case .bash: return "shell"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "cpp"
		case .rust: return "rust"
		case .java: return "java"
		case .sql: return "sql"
		}
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
				
				Button("Run") { executeCode() }
				.disabled(isRunning)
				
				Button("Save") { saveFile() }
				
				Button("Load") { showFileManager = true }
				
				Button("Export") { showExportOptions = true }
				
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
						FallbackCodeEditor(code: $savedCode)
					} else {
						WebViewHTML(html: html(savedCode), savedCode: savedCode) { newCode in 
							savedCode = newCode 
						}
						.onAppear {
							LoadingStateManager.shared.startMonacoLoading("Initializing Monaco editor...")
							// Set a timeout to fallback if WebView doesn't load
							DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
								if !useFallback {
									useFallback = true
									LoadingStateManager.shared.stopMonacoLoading()
								}
							}
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
		.onChange(of: selectedLanguage) {
			// Update Monaco language when selection changes
			updateMonacoLanguage()
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
	
	private func updateMonacoLanguage() {
		// This would need to be implemented in the WebView coordinator
		// For now, we'll reload the WebView with the new language
	}
}

// MARK: - File Manager View
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
					Button("New File") { newFile() }
					Button("Delete Selected") { deleteFile() }
						.disabled(selectedFile == nil)
				}
				.padding()
			}
		}
		.frame(width: 500, height: 400)
		.onAppear { loadRecentFiles() }
	}
	
	private func loadRecentFiles() {
		// Load recent files from a directory
		let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let codeFilesPath = documentsPath.appendingPathComponent("DevReader/CodeFiles")
		
		do {
			try FileManager.default.createDirectory(at: codeFilesPath, withIntermediateDirectories: true)
			files = try FileManager.default.contentsOfDirectory(at: codeFilesPath, includingPropertiesForKeys: nil)
				.filter { $0.pathExtension != "" }
		} catch {
			files = []
		}
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
			
			dismiss()
		} catch {
			print("Error loading file: \(error)")
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
			print("Error deleting file: \(error)")
		}
	}
}

// MARK: - Export Options View
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
				Button("Export to Vim Configuration") { exportToVim() }
				Button("Export to Emacs Configuration") { exportToEmacs() }
				Button("Export to JetBrains Project") { exportToJetBrains() }
				Button("Export as Standalone File") { exportAsFile() }
			}
			
			HStack {
				Button("Cancel") { dismiss() }
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
					"*.\(language.fileExtension)": "\(getMonacoLanguage(language))"
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
		case .sql: return "sql"
		}
	}
	
	private func getMonacoLanguage(_ lang: CodeLang) -> String {
		switch lang {
		case .python: return "python"
		case .ruby: return "ruby"
		case .node, .javascript: return "javascript"
		case .swift: return "swift"
		case .bash: return "shell"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "cpp"
		case .rust: return "rust"
		case .java: return "java"
		case .sql: return "sql"
		}
	}
}

struct FallbackCodeEditor: View {
	@Binding var code: String
	var body: some View {
		VStack {
			Text("Monaco Editor (Fallback Mode)")
				.font(.caption)
				.foregroundColor(.secondary)
				.padding(.horizontal)
			TextEditor(text: $code)
				.font(.system(.body, design: .monospaced))
				.padding(8)
		}
	}
}

struct WebViewHTML: NSViewRepresentable {
    var html: String
    var savedCode: String
    var onCodeChange: (String) -> Void
    func makeCoordinator() -> Coord { Coord(onCodeChange: onCodeChange, savedCode: savedCode) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Configure JavaScript settings with better error handling
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Configure website data store
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // Configure process pool to prevent crashes
        config.processPool = WKProcessPool()
        
        // Set user agent
        config.applicationNameForUserAgent = "DevReader/1.0"
        
        // Add message handler with error handling
        config.userContentController.add(context.coordinator, name: "codeChanged")
        config.userContentController.add(context.coordinator, name: "editorError")
        config.userContentController.add(context.coordinator, name: "editorReady")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "DevReader/1.0"
        
        // Set accessibility
        webView.setAccessibilityLabel("Code Editor")
        webView.setAccessibilityRole(.group)
        
        // Add error handling
        webView.setValue(false, forKey: "drawsBackground")
        
        return webView
    }
    func updateNSView(_ view: WKWebView, context: Context) { 
        if view.url == nil {
            view.loadHTMLString(html, baseURL: URL(string: "https://cdn.jsdelivr.net"))
        }
    }
    final class Coord: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onCodeChange: (String) -> Void
        let savedCode: String
        init(onCodeChange: @escaping (String) -> Void, savedCode: String) { 
            self.onCodeChange = onCodeChange
            self.savedCode = savedCode 
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "codeChanged":
                if let text = message.body as? String { 
                    onCodeChange(text) 
                }
            case "editorError":
                if let error = message.body as? String {
                    print("Monaco Editor Error: \(error)")
                }
            case "editorReady":
                print("Monaco Editor Ready")
                LoadingStateManager.shared.stopMonacoLoading()
            default:
                break
            }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let escaped = self.savedCode
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "'", with: "\\'")
                let js = "if (window.editor) { window.editor.setValue('\(escaped)'); } else { window._code = '\(escaped)'; }"
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("JavaScript evaluation failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Monaco WebView navigation failed: \(error.localizedDescription)")
            // Try to reload with fallback content
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                webView.loadHTMLString("<html><body><h1>Editor Loading Failed</h1><p>Please try refreshing the editor.</p></body></html>", baseURL: nil)
            }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Monaco WebView provisional navigation failed: \(error.localizedDescription)")
            // Try to reload with fallback content
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                webView.loadHTMLString("<html><body><h1>Editor Loading Failed</h1><p>Please try refreshing the editor.</p></body></html>", baseURL: nil)
            }
        }
    }
}
