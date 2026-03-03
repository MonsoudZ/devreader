import SwiftUI
import PDFKit
import Combine

@MainActor
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
		let documentChanged = nsView.document !== pdf.document
		if documentChanged {
			nsView.document = pdf.document
			context.coordinator.hasSetInitialZoom = false
		}

		// Only navigate to page if it's different and valid (with safety checks)
		if let doc = pdf.document,
		   pdf.currentPageIndex >= 0,
		   pdf.currentPageIndex < doc.pageCount,
		   let targetPage = doc.page(at: pdf.currentPageIndex),
		   nsView.currentPage !== targetPage {
			nsView.go(to: targetPage)
		}

		// Only set zoom when the document changes, not on every update
		// This prevents overriding the user's manual pinch-zoom
		if !context.coordinator.hasSetInitialZoom, pdf.document != nil {
			let safeZoom = max(0.3, min(defaultZoom, 2.0))
			if safeZoom > 0 {
				nsView.scaleFactor = safeZoom
			}
			context.coordinator.hasSetInitialZoom = true
		}
	}

	func makeCoordinator() -> Coord { Coord(parent: self) }

	final class Coord: NSObject, PDFViewDelegate {
		let parent: PDFViewRepresentable
		var hasSetInitialZoom = false

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

	}
}
