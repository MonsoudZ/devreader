import SwiftUI
import WebKit
import AppKit
import Foundation
import os.log

struct WebPane: View {
	@State private var urlString: String = "https://developer.apple.com/documentation/pdfkit"
	@State private var currentURL: URL?
	@State private var history: [URL] = []
	@State private var historyIndex: Int = -1
	@State private var bookmarks: [URL] = []

	private let bookmarksKey = "DevReader.Web.Bookmarks.v1"

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 6) {
				Button {
					goBack()
				} label: {
					Label("Back", systemImage: "chevron.left")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.disabled(!canGoBack)
				.accessibilityIdentifier("webBack")

				Button {
					goForward()
				} label: {
					Label("Forward", systemImage: "chevron.right")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.disabled(!canGoForward)
				.accessibilityIdentifier("webForward")

				TextField("Enter URL…", text: $urlString).onSubmit { loadURL() }
					.accessibilityIdentifier("webURLField")

				Button("Go") { loadURL() }
					.buttonStyle(.bordered)
					.controlSize(.small)
					.accessibilityIdentifier("webGoButton")

				Menu {
					ForEach(bookmarks, id: \.self) { u in Button(u.absoluteString) { openURL(u) } }
					Divider()
					Button(isBookmarked(currentURL) ? "Remove Bookmark" : "Add Bookmark") { toggleBookmark() }.disabled(currentURL == nil)
				} label: {
					Label("Bookmarks", systemImage: "bookmark")
				}
				.accessibilityIdentifier("webBookmarks")

				Menu {
					ForEach(history, id: \.self) { u in Button(u.absoluteString) { openURL(u) } }
				} label: {
					Label("History", systemImage: "clock")
				}
				.accessibilityIdentifier("webHistory")

				Button {
					if let u = currentURL { NSWorkspace.shared.open(u) }
				} label: {
					Label("Open in Browser", systemImage: "safari")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.disabled(currentURL == nil)
				.accessibilityIdentifier("webOpenInBrowser")
			}.padding(8)
			Divider()
			WebView(url: currentURL) { newURL in onNavigated(newURL) }
		}
		.onAppear { loadBookmarks(); if let u = URL(string: urlString) { openURL(u, record: true) } }
	}

	private var canGoBack: Bool { historyIndex > 0 }
	private var canGoForward: Bool { historyIndex >= 0 && historyIndex < history.count - 1 }
	private func loadURL() {
		if let url = URL(string: urlString) {
			LoadingStateManager.shared.startWebLoading("Loading webpage...")
			openURL(url, record: true)
		}
	}
	private func openURL(_ url: URL, record: Bool = false) {
		currentURL = url
		urlString = url.absoluteString
		if record { appendHistory(url) }
	}
	private func onNavigated(_ url: URL?) { if let u = url { openURL(u, record: true) } }
	private func appendHistory(_ url: URL) {
		if historyIndex >= 0 && historyIndex < history.count - 1 { history = Array(history.prefix(historyIndex + 1)) }
		if history.last != url { history.append(url); historyIndex = history.count - 1 }
	}
	private func goBack() {
		guard canGoBack else { return }
		historyIndex -= 1
		currentURL = history[historyIndex]
		urlString = currentURL?.absoluteString ?? urlString
	}
	private func goForward() {
		guard canGoForward else { return }
		historyIndex += 1
		currentURL = history[historyIndex]
		urlString = currentURL?.absoluteString ?? urlString
	}
	private func toggleBookmark() {
		guard let u = currentURL else { return }
		if let i = bookmarks.firstIndex(of: u) { bookmarks.remove(at: i) } else { bookmarks.insert(u, at: 0) }
		saveBookmarks()
	}
	private func isBookmarked(_ url: URL?) -> Bool { guard let u = url else { return false }; return bookmarks.contains(u) }
	private func loadBookmarks() { if let arr: [URL] = PersistenceService.loadCodable([URL].self, forKey: bookmarksKey) { bookmarks = arr } }
	private func saveBookmarks() { PersistenceService.saveCodable(bookmarks, forKey: bookmarksKey) }
}

struct WebView: NSViewRepresentable {
    var url: URL?
    var onNavigated: (URL?) -> Void
    func makeCoordinator() -> Coord { Coord(onNavigated: onNavigated) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Configure JavaScript settings (modern API)
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Ephemeral data store — no persistent cookies or cache across sessions
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // Set user agent
        config.applicationNameForUserAgent = "DevReader/1.0"

        let v = WKWebView(frame: .zero, configuration: config)
        v.navigationDelegate = context.coordinator
        v.customUserAgent = "DevReader/1.0"

        // Set accessibility
        v.setAccessibilityLabel("Web Browser")
        v.setAccessibilityRole(.group)

        return v
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        if let u = url, view.url != u {
            let request = URLRequest(url: u)
            view.load(request)
        }
    }
    @MainActor final class Coord: NSObject, WKNavigationDelegate {
        let onNavigated: (URL?) -> Void
        init(onNavigated: @escaping (URL?) -> Void) { self.onNavigated = onNavigated }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            LoadingStateManager.shared.stopWebLoading()
            onNavigated(webView.url)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            LoadingStateManager.shared.stopWebLoading()
            logError(AppLog.web, "WebView navigation failed: \(error.localizedDescription)")
            showErrorPage(in: webView, error: error)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            LoadingStateManager.shared.stopWebLoading()
            logError(AppLog.web, "WebView provisional navigation failed: \(error.localizedDescription)")
            showErrorPage(in: webView, error: error)
        }
        private func showErrorPage(in webView: WKWebView, error: Error) {
            let html = """
            <html><head><style>
            body { font-family: -apple-system; text-align: center; padding: 60px 20px; color: #888; background: \
            #1e1e1e; }
            h2 { color: #ccc; } p { margin-top: 8px; }
            </style></head><body>
            <h2>Page Failed to Load</h2>
            <p>\(error.localizedDescription)</p>
            <p style="margin-top:20px;font-size:13px;color:#666">Check your connection and try again.</p>
            </body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
               scheme != "http" && scheme != "https" && scheme != "about" {
                decisionHandler(.cancel, preferences)
                return
            }
            preferences.allowsContentJavaScript = true
            decisionHandler(.allow, preferences)
        }
    }
}
