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
	@AppStorage("monacoCode") private var savedCode: String = ""
	@State private var useFallback = false
	
	private func html(_ initial: String) -> String {
		return """
		<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
		<style>html,body,#container{height:100%;margin:0}#container{display:flex;flex-direction:column}#editor{flex:1;}</style>
		<script src=\"https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js\"></script>
		<script>
		require.config({ paths: { 'vs': 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs' } });
		window._code = `\(initial.replacingOccurrences(of: "`", with: "\\`"))`;
		require(['vs/editor/editor.main'], function(){
		  window.editor = monaco.editor.create(document.getElementById('editor'), { value: window._code, language: 'javascript', automaticLayout: true });
		  window.editor.onDidChangeModelContent(function(){
		    try { window.webkit.messageHandlers.codeChanged.postMessage(window.editor.getValue()); } catch(e) { }
		  });
		});
		</script>
		</head><body><div id=\"container\"><div id=\"editor\"></div></div></body></html>
		"""
	}
	
	var body: some View { 
		if useFallback {
			FallbackCodeEditor(code: $savedCode)
		} else {
			WebViewHTML(html: html(savedCode), savedCode: savedCode) { newCode in 
				savedCode = newCode 
			}
			.onAppear {
				// Set a timeout to fallback if WebView doesn't load
				DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
					if !useFallback {
						useFallback = true
					}
				}
			}
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
        
        // Configure JavaScript settings
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Configure website data store
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // Configure process pool to prevent crashes
        config.processPool = WKProcessPool()
        
        // Set user agent
        config.applicationNameForUserAgent = "DevReader/1.0"
        
        // Add message handler
        config.userContentController.add(context.coordinator, name: "codeChanged")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "DevReader/1.0"
        
        // Set accessibility
        webView.setAccessibilityLabel("Code Editor")
        webView.setAccessibilityRole(.group)
        
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
            if message.name == "codeChanged", let text = message.body as? String { 
                onCodeChange(text) 
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
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Monaco WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
