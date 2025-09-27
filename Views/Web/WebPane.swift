import SwiftUI
import WebKit
import AppKit
import Foundation

struct WebPane: View {
	@State private var urlString: String = "https://developer.apple.com/documentation/pdfkit"
	@State private var currentURL: URL?
	@State private var history: [URL] = []
	@State private var historyIndex: Int = -1
	@State private var bookmarks: [URL] = []

	private let bookmarksKey = "DevReader.Web.Bookmarks.v1"
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Button("Back") { goBack() }.disabled(!canGoBack)
				Button("Forward") { goForward() }.disabled(!canGoForward)
				Divider()
				TextField("Enter URL…", text: $urlString).onSubmit { loadURL() }
				Button("Go") { loadURL() }
				Divider()
				Menu("Bookmarks") {
					ForEach(bookmarks, id: \.self) { u in Button(u.absoluteString) { openURL(u) } }
					Divider()
					Button(isBookmarked(currentURL) ? "Remove Bookmark" : "Add Bookmark") { toggleBookmark() }.disabled(currentURL == nil)
				}
				Menu("History") {
					ForEach(history, id: \.self) { u in Button(u.absoluteString) { openURL(u) } }
				}
				Button("Open in Browser") { if let u = currentURL { NSWorkspace.shared.open(u) } }.disabled(currentURL == nil)
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
		urlString = currentURL!.absoluteString
	}
	private func goForward() {
		guard canGoForward else { return }
		historyIndex += 1
		currentURL = history[historyIndex]
		urlString = currentURL!.absoluteString
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
        
        // Configure JavaScript settings
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Configure website data store
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // Configure process pool to prevent crashes
        config.processPool = WKProcessPool()
        
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
    final class Coord: NSObject, WKNavigationDelegate {
        let onNavigated: (URL?) -> Void
        init(onNavigated: @escaping (URL?) -> Void) { self.onNavigated = onNavigated }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { 
            LoadingStateManager.shared.stopWebLoading()
            onNavigated(webView.url) 
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            LoadingStateManager.shared.stopWebLoading()
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            LoadingStateManager.shared.stopWebLoading()
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
