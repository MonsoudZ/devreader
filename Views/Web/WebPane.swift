import SwiftUI
import WebKit

struct WebPane: View {
	@State private var urlString: String = "https://developer.apple.com/documentation/pdfkit"
	@State private var currentURL: URL?
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				TextField("Enter URL…", text: $urlString).onSubmit { loadURL() }
				Button("Go") { loadURL() }
			}.padding(8)
			Divider()
			WebView(url: currentURL)
		}
		.onAppear { currentURL = URL(string: urlString) }
	}
	
	private func loadURL() { if let url = URL(string: urlString) { currentURL = url } }
}

struct WebView: NSViewRepresentable {
	var url: URL?
	func makeNSView(context: Context) -> WKWebView { WKWebView() }
	func updateNSView(_ view: WKWebView, context: Context) { if let u = url { view.load(URLRequest(url: u)) } }
}
