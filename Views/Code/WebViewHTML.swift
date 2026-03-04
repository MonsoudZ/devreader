import SwiftUI
import WebKit
import os.log

struct WebViewHTML: NSViewRepresentable {
    var html: String
    var savedCode: String
    var language: String
    var theme: String
    var onCodeChange: @MainActor @Sendable (String) -> Void
    var onEditorReady: (@MainActor @Sendable () -> Void)?
    func makeCoordinator() -> Coord { Coord(onCodeChange: onCodeChange, savedCode: savedCode, theme: theme, onEditorReady: onEditorReady) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Configure JavaScript settings with better error handling (modern API)
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Configure website data store
        config.websiteDataStore = WKWebsiteDataStore.default()

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
            context.coordinator.currentLanguage = language
            context.coordinator.currentTheme = theme
        } else {
            if context.coordinator.currentLanguage != language {
                context.coordinator.currentLanguage = language
                let escaped = language.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
                let js = "if (window.editor) { monaco.editor.setModelLanguage(window.editor.getModel(), '\(escaped)'); }"
                view.evaluateJavaScript(js) { _, error in
                    if let error = error { logError(AppLog.code, "Language change failed: \(error.localizedDescription)") }
                }
            }
            if context.coordinator.currentTheme != theme {
                context.coordinator.currentTheme = theme
                let escapedTheme = theme.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                let js = "if (window.monaco) { monaco.editor.setTheme('\(escapedTheme)'); }"
                view.evaluateJavaScript(js) { _, error in
                    if let error = error { logError(AppLog.code, "Theme change failed: \(error.localizedDescription)") }
                }
            }
        }
    }
    @MainActor final class Coord: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onCodeChange: @MainActor @Sendable (String) -> Void
        let savedCode: String
        let onEditorReady: (@MainActor @Sendable () -> Void)?
        var currentLanguage: String = ""
        var currentTheme: String = ""
        init(onCodeChange: @escaping @MainActor @Sendable (String) -> Void, savedCode: String, theme: String = "vs-dark", onEditorReady: (@MainActor @Sendable () -> Void)? = nil) {
            self.onCodeChange = onCodeChange
            self.savedCode = savedCode
            self.currentTheme = theme
            self.onEditorReady = onEditorReady
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "codeChanged":
                if let text = message.body as? String {
                    onCodeChange(text)
                }
            case "editorError":
                if let error = message.body as? String {
                    logError(AppLog.code, "Monaco Editor Error: \(error)")
                }
            case "editorReady":
                log(AppLog.code, "Monaco Editor Ready")
                LoadingStateManager.shared.stopMonacoLoading()
                onEditorReady?()
            default:
                break
            }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let escaped = self.savedCode
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\0", with: "\\0")
                    .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                    .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
                let js = "if (window.editor) { window.editor.setValue('\(escaped)'); } else { window._code = '\(escaped)'; }"
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        logError(AppLog.code, "JavaScript evaluation failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logError(AppLog.code, "Monaco WebView navigation failed: \(error.localizedDescription)")
            // Try to reload with fallback content
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                webView.loadHTMLString("<html><body><h1>Editor Loading Failed</h1><p>Please try refreshing the editor.</p></body></html>", baseURL: nil)
            }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            logError(AppLog.code, "Monaco WebView provisional navigation failed: \(error.localizedDescription)")
            // Try to reload with fallback content
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                webView.loadHTMLString("<html><body><h1>Editor Loading Failed</h1><p>Please try refreshing the editor.</p></body></html>", baseURL: nil)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // Enable JavaScript using the modern API for Monaco editor
            preferences.allowsContentJavaScript = true
            decisionHandler(.allow, preferences)
        }
    }
}
