import SwiftUI
import PDFKit
import Combine

final class PDFSelectionBridge {
	static let shared = PDFSelectionBridge()
	weak var pdfView: PDFView?
	var cancellables = Set<AnyCancellable>()
	var currentSelection: PDFSelection? { pdfView?.currentSelection }
}

struct PDFViewRepresentable: NSViewRepresentable {
	@ObservedObject var pdf: PDFController
	
	func makeNSView(context: Context) -> PDFView {
		let v = PDFView()
		v.autoScales = true
		v.displayMode = .singlePageContinuous
		v.backgroundColor = .windowBackgroundColor
		v.delegate = context.coordinator
		PDFSelectionBridge.shared.pdfView = v
		let defaultZoom = UserDefaults.standard.double(forKey: "defaultZoom")
		if defaultZoom > 0 { v.scaleFactor = defaultZoom }
		return v
	}
	
	func updateNSView(_ nsView: PDFView, context: Context) {
		if nsView.document != pdf.document { nsView.document = pdf.document }
		if let doc = pdf.document, pdf.currentPageIndex < doc.pageCount {
			let targetPage = doc.page(at: pdf.currentPageIndex)!
			if nsView.currentPage != targetPage { nsView.go(to: targetPage) }
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
	}
}
