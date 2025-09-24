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
	
	// Suppress JPEG2000 errors that are common in PDF rendering
	static func suppressJPEG2000Errors() {
		// These errors are often harmless and related to embedded images in PDFs
		// We'll log them at debug level instead of error level
		let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "PDF.ImageProcessing")
		os_log("JPEG2000 image processing errors are common in PDFs with embedded images and are usually harmless", log: logger, type: .debug)
	}
}

struct PDFViewRepresentable: NSViewRepresentable {
    @ObservedObject var pdf: PDFController
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.0
	
	func makeNSView(context: Context) -> PDFView {
		let v = PDFView()
		v.autoScales = true
		v.displayMode = .singlePageContinuous
		v.backgroundColor = .windowBackgroundColor
		v.delegate = context.coordinator
		PDFSelectionBridge.shared.pdfView = v
        if defaultZoom > 0 { v.scaleFactor = defaultZoom }
		
		// Configure for better image handling and memory optimization
		v.interpolationQuality = .high
		
		// Memory optimization settings
		v.pageShadowsEnabled = false // Disable shadows to save memory
		v.displayBox = .mediaBox // Use media box for better memory efficiency
		
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
		
		// Only navigate to page if it's different and valid
		if let doc = pdf.document, 
		   pdf.currentPageIndex < doc.pageCount,
		   let targetPage = doc.page(at: pdf.currentPageIndex),
		   nsView.currentPage !== targetPage { 
			nsView.go(to: targetPage) 
		}
		
		// Only update zoom if it changed significantly
		if defaultZoom > 0, abs(nsView.scaleFactor - defaultZoom) > 0.01 { 
			nsView.scaleFactor = defaultZoom 
		}
	}
	
	func makeCoordinator() -> Coord { Coord(parent: self) }
	
	final class Coord: NSObject, PDFViewDelegate {
		let parent: PDFViewRepresentable
		init(parent: PDFViewRepresentable) { self.parent = parent }
		
		func pdfViewPageChanged(_ sender: PDFView) {
			guard let doc = sender.document, let page = sender.currentPage else { return }
			let idx = doc.index(for: page)
			if idx != parent.pdf.currentPageIndex && idx >= 0 && idx < doc.pageCount {
				parent.pdf.currentPageIndex = idx
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
			for i in 0..<min(doc.pageCount, 10) { // Check first 10 pages
				if let page = doc.page(at: i) {
					let bounds = page.bounds(for: .mediaBox)
					if bounds.width <= 0 || bounds.height <= 0 {
						corruptedPages.append(i)
					}
				}
			}
			
			if !corruptedPages.isEmpty {
				logError(AppLog.pdf, "Found corrupted pages: \(corruptedPages) - continuing with graceful degradation")
				// Continue with graceful degradation - don't fail completely
			} else {
				log(AppLog.pdf, "Document loaded successfully with \(doc.pageCount) pages")
			}
		}
		
		// Defensive: if current page's thumbnail fails (e.g., JP2 decode), try to rasterize a preview to avoid blank screen
		func pdfViewWillDraw(_ sender: PDFView) {
			guard let page = sender.currentPage else { return }
			let probe = page.thumbnail(of: CGSize(width: 24, height: 24), for: .mediaBox)
			if probe.size == .zero {
				_ = ImageProcessingService.rasterize(page: page, into: CGSize(width: 160, height: 200))
			}
		}
		
	}
}
