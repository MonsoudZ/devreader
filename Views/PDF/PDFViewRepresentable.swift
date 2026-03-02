import SwiftUI
import PDFKit
import Combine
import os.log

final class PDFSelectionBridge {
	static let shared = PDFSelectionBridge()
	weak var pdfView: PDFView?
	var cancellables = Set<AnyCancellable>()
	var currentSelection: PDFSelection? { pdfView?.currentSelection }
    func setHighlightedSelections(_ selections: [PDFSelection]) { pdfView?.highlightedSelections = selections }
}

struct PDFViewRepresentable: NSViewRepresentable {
    @ObservedObject var pdf: PDFController
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.0

	func makeNSView(context: Context) -> PDFView {
		let v = PDFView()

		// Basic configuration
		v.autoScales = false
		v.displayMode = .singlePageContinuous
		v.backgroundColor = .windowBackgroundColor
		v.delegate = context.coordinator
		PDFSelectionBridge.shared.pdfView = v

		// Aggressive memory optimization
		v.interpolationQuality = .low
		v.pageShadowsEnabled = false
		v.displayBox = .mediaBox
		v.pageBreakMargins = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

		// Conservative scaling limits
		v.maxScaleFactor = 2.0
		v.minScaleFactor = 0.3

		// Set initial zoom
		if defaultZoom > 0 {
			v.scaleFactor = min(defaultZoom, 1.5)
		}

		// Large PDF optimizations
		if pdf.isLargePDF {
			v.pageShadowsEnabled = false
			v.interpolationQuality = .low
			v.autoScales = false
		}

		// Accessibility support
		v.setAccessibilityLabel("PDF Document")
		v.setAccessibilityRole(.group)
		v.setAccessibilityHelp("PDF document viewer. Use arrow keys to navigate pages, Command+F to search, and Command+Plus/Minus to zoom.")

		return v
	}

	func updateNSView(_ nsView: PDFView, context: Context) {
		// Only update document if it actually changed
		if nsView.document !== pdf.document {
			nsView.document = pdf.document
		}

		// Only navigate to page if it's different and valid (with safety checks)
		if let doc = pdf.document,
		   pdf.currentPageIndex >= 0,
		   pdf.currentPageIndex < doc.pageCount,
		   let targetPage = doc.page(at: pdf.currentPageIndex),
		   nsView.currentPage !== targetPage {
			nsView.go(to: targetPage)
		}

		// Only update zoom if it changed significantly and is within safe bounds
		let safeZoom = max(0.3, min(defaultZoom, 2.0))
		if safeZoom > 0, abs(nsView.scaleFactor - safeZoom) > 0.01 {
			nsView.scaleFactor = safeZoom
		}
	}

	func makeCoordinator() -> Coord { Coord(parent: self) }

	final class Coord: NSObject, PDFViewDelegate {
		let parent: PDFViewRepresentable

		init(parent: PDFViewRepresentable) {
			self.parent = parent
			super.init()
		}

		func pdfViewPageChanged(_ sender: PDFView) {
			guard let doc = sender.document, let page = sender.currentPage else { return }
			let idx = doc.index(for: page)
			if idx != parent.pdf.currentPageIndex && idx >= 0 && idx < doc.pageCount {
				parent.pdf.didScrollToPage(idx)
			}
		}

		// Handle PDF loading errors gracefully
		func pdfView(_ sender: PDFView, didFailToLoadWithError error: Error) {
			logError(AppLog.pdf, "PDFView failed to load: \(error.localizedDescription)")
			NotificationCenter.default.post(name: .pdfLoadError, object: sender.document?.documentURL)
		}

		// Handle document loading completion
		func pdfViewDidChangeDocument(_ sender: PDFView) {
			guard let doc = sender.document else { return }

			// Validate document integrity
			if doc.pageCount == 0 {
				logError(AppLog.pdf, "Document has no pages")
				NotificationCenter.default.post(name: .pdfLoadError, object: doc.documentURL)
				return
			}

			// Check for corrupted pages with better error handling
			var corruptedPages: [Int] = []
			for i in 0..<min(doc.pageCount, 10) {
				if let page = doc.page(at: i) {
					let bounds = page.bounds(for: .mediaBox)
					if bounds.width <= 0 || bounds.height <= 0 {
						corruptedPages.append(i)
					}
				}
			}

			if !corruptedPages.isEmpty {
				logError(AppLog.pdf, "Found corrupted pages: \(corruptedPages) - continuing with graceful degradation")
			} else {
				log(AppLog.pdf, "Document loaded successfully with \(doc.pageCount) pages")
			}
		}

		func pdfViewWillDraw(_ sender: PDFView) {
			guard let page = sender.currentPage else { return }

			// Check for memory pressure and optimize accordingly
			if ProcessInfo.processInfo.isLowPowerModeEnabled {
				sender.interpolationQuality = .low
			}

			// Try to get a thumbnail with error handling
			let probe = page.thumbnail(of: CGSize(width: 24, height: 24), for: .mediaBox)
			if probe.size == .zero {
				_ = ImageProcessingService.rasterize(page: page, into: CGSize(width: 160, height: 200))
			}
		}

	}
}
