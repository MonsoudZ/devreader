import SwiftUI
import PDFKit

struct PDFPane: View {
	@ObservedObject var pdf: PDFController
	@ObservedObject var notes: NotesStore
	
	var body: some View {
		VStack(spacing: 0) {
			PDFViewRepresentable(pdf: pdf)
			HStack {
				if let doc = pdf.document { Text("Page \(pdf.currentPageIndex + 1) / \(doc.pageCount)") }
				Spacer()
				if let title = pdf.outlineMap[pdf.currentPageIndex], !title.isEmpty {
					Text(title).font(.caption).foregroundStyle(.secondary)
				}
			}
			.padding(6)
		}
		.background(Color(NSColor.textBackgroundColor))
	}
}
