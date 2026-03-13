import SwiftUI
import WebKit
import AppKit
import Foundation
import Combine
import os.log

struct WebPane: View {
	@State private var urlString: String = "https://developer.apple.com/documentation/pdfkit"
	@State private var currentURL: URL?
	@State private var history: [URL] = []
	@State private var historyIndex: Int = -1
	@State private var bookmarks: [URL] = []
	@State private var isLoading: Bool = false
	@StateObject private var webActions = WebViewActions()

	private let bookmarksKey = "DevReader.Web.Bookmarks.v1"

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: DS.Spacing.xs) {
				Button {
					goBack()
				} label: {
					Label("Back", systemImage: "chevron.left")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(DSToolbarButtonStyle())
				.disabled(!canGoBack)
				.accessibilityIdentifier("webBack")

				Button {
					goForward()
				} label: {
					Label("Forward", systemImage: "chevron.right")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(DSToolbarButtonStyle())
				.disabled(!canGoForward)
				.accessibilityIdentifier("webForward")

				if isLoading {
					Button {
						webActions.stop?()
					} label: {
						Label("Stop", systemImage: "xmark")
							.labelStyle(.iconOnly)
					}
					.buttonStyle(DSToolbarButtonStyle())
					.accessibilityIdentifier("webStop")
					.accessibilityLabel("Stop loading")
				} else {
					Button {
						webActions.reload?()
					} label: {
						Label("Reload", systemImage: "arrow.clockwise")
							.labelStyle(.iconOnly)
					}
					.buttonStyle(DSToolbarButtonStyle())
					.disabled(currentURL == nil)
					.accessibilityIdentifier("webReload")
					.accessibilityLabel("Reload page")
				}

				TextField("Enter URL…", text: $urlString).onSubmit { loadURL() }
					.accessibilityIdentifier("webURLField")

				Button("Go") { loadURL() }
					.buttonStyle(DSSecondaryButtonStyle())
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
				.buttonStyle(DSToolbarButtonStyle())
				.disabled(currentURL == nil)
				.accessibilityIdentifier("webOpenInBrowser")
			}.padding(DS.Spacing.sm)
			Divider()
			WebView(url: currentURL, actions: webActions) { newURL in
				onNavigated(newURL)
			} onLoadingChanged: { loading in
				isLoading = loading
			}
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
	private static let maxHistorySize = 100

	private func appendHistory(_ url: URL) {
		if historyIndex >= 0 && historyIndex < history.count - 1 { history = Array(history.prefix(historyIndex + 1)) }
		if history.last != url {
			history.append(url)
			if history.count > Self.maxHistorySize {
				history.removeFirst()
				historyIndex = max(-1, historyIndex - 1)
			}
			historyIndex = history.count - 1
		}
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
	private func saveBookmarks() {
		do {
			try PersistenceService.saveCodable(bookmarks, forKey: bookmarksKey)
		} catch {
			logError(AppLog.persistence, "Failed to save web bookmarks: \(error.localizedDescription)")
		}
	}
}

// MARK: - Web View Actions

@MainActor
final class WebViewActions: ObservableObject {
	var reload: (() -> Void)?
	var stop: (() -> Void)?
}

// MARK: - WKWebView Wrapper

struct WebView: NSViewRepresentable {
    var url: URL?
    var actions: WebViewActions
    var onNavigated: (URL?) -> Void
    var onLoadingChanged: (Bool) -> Void

    func makeCoordinator() -> Coord { Coord(onNavigated: onNavigated, onLoadingChanged: onLoadingChanged) }
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

        // Wire up reload/stop actions
        actions.reload = { [weak v] in v?.reload() }
        actions.stop = { [weak v] in v?.stopLoading() }

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
        let onLoadingChanged: (Bool) -> Void
        init(onNavigated: @escaping (URL?) -> Void, onLoadingChanged: @escaping (Bool) -> Void) {
            self.onNavigated = onNavigated
            self.onLoadingChanged = onLoadingChanged
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onLoadingChanged(true)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            LoadingStateManager.shared.stopWebLoading()
            onLoadingChanged(false)
            onNavigated(webView.url)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            LoadingStateManager.shared.stopWebLoading()
            onLoadingChanged(false)
            logError(AppLog.web, "WebView navigation failed: \(error.localizedDescription)")
            showErrorPage(in: webView, error: error)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            LoadingStateManager.shared.stopWebLoading()
            onLoadingChanged(false)
            logError(AppLog.web, "WebView provisional navigation failed: \(error.localizedDescription)")
            showErrorPage(in: webView, error: error)
        }
        private func showErrorPage(in webView: WKWebView, error: Error) {
            let nsError = error as NSError
            let message: String
            switch (nsError.domain, nsError.code) {
            case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
                 (NSURLErrorDomain, NSURLErrorNetworkConnectionLost):
                message = "No internet connection."
            case (NSURLErrorDomain, NSURLErrorTimedOut):
                message = "The request timed out."
            case (NSURLErrorDomain, NSURLErrorCannotFindHost):
                message = "The server could not be found."
            case (NSURLErrorDomain, NSURLErrorSecureConnectionFailed),
                 (NSURLErrorDomain, NSURLErrorServerCertificateUntrusted):
                message = "A secure connection could not be established."
            case (NSURLErrorDomain, NSURLErrorCancelled):
                return // User-initiated cancel — no error page needed
            default:
                message = "An error occurred while loading the page."
            }
            let html = """
            <html><head><style>
            body { font-family: -apple-system; text-align: center; padding: 60px 20px; }
            @media (prefers-color-scheme: dark) {
              body { background: #1e1e1e; color: #888; }
              h2 { color: #ccc; }
              .hint { color: #666; }
            }
            @media (prefers-color-scheme: light) {
              body { background: #f5f5f5; color: #555; }
              h2 { color: #333; }
              .hint { color: #999; }
            }
            p { margin-top: 8px; }
            </style></head><body>
            <h2>Page Failed to Load</h2>
            <p>\(message)</p>
            <p class="hint" style="margin-top:20px;font-size:13px;">Check your connection and try again.</p>
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
