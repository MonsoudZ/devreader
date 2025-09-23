import SwiftUI
import WebKit

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
	@State private var code: String = """
# Write some quick test code and run it.
# Example:
# print('hello from DevReader!')
"""
	@State private var output: String = ""
	@State private var isRunning = false
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Picker("Lang", selection: $language) {
					Text("Python").tag(CodeLang.python)
					Text("Ruby").tag(CodeLang.ruby)
					Text("Node").tag(CodeLang.node)
				}.pickerStyle(.segmented)
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
	}
	
	func run() {
		isRunning = true; output = ""
		DispatchQueue.global(qos: .userInitiated).async {
			let result = Shell.run(language.command, args: language.args, stdin: code)
			DispatchQueue.main.async { self.output = result; self.isRunning = false }
		}
	}
}

enum CodeLang { case python, ruby, node
	var command: String { "/usr/bin/env" }
	var args: [String] {
		switch self {
		case .python: return ["python3", "-"]
		case .ruby:   return ["ruby", "-"]
		case .node:   return ["node", "-"]
		}
	}
}

struct MonacoWebEditor: View {
	private let html: String = {
		return """
		<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
		<style>html,body,#container{height:100%;margin:0}#container{display:flex;flex-direction:column}#editor{flex:1;}</style>
		<script src=\"https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js\"></script>
		<script>
		require.config({ paths: { 'vs': 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs' } });
		window._code = `// Monaco editor loaded. Happy hacking!\\n`;
		require(['vs/editor/editor.main'], function(){
		  window.editor = monaco.editor.create(document.getElementById('editor'), { value: window._code, language: 'javascript', automaticLayout: true });
		});
		</script>
		</head><body><div id=\"container\"><div id=\"editor\"></div></div></body></html>
		"""
	}()
	
	var body: some View { WebViewHTML(html: html) }
}

struct WebViewHTML: NSViewRepresentable {
	var html: String
	func makeNSView(context: Context) -> WKWebView { WKWebView() }
	func updateNSView(_ view: WKWebView, context: Context) { view.loadHTMLString(html, baseURL: nil) }
}
