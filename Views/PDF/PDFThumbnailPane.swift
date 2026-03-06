import SwiftUI
import PDFKit

struct PDFThumbnailPane: View {
	@ObservedObject var pdf: PDFController
	private let thumbnailSize = CGSize(width: 120, height: 160)

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Pages").font(.headline)
				Spacer()
				Text("\(pdf.document?.pageCount ?? 0) pages")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.padding(8)
			Divider()

			if let doc = pdf.document {
				ScrollViewReader { proxy in
					ScrollView {
						LazyVStack(spacing: 8) {
							ForEach(0..<doc.pageCount, id: \.self) { index in
								thumbnailRow(doc: doc, index: index)
									.id(index)
							}
						}
						.padding(8)
					}
					.onChange(of: pdf.currentPageIndex) { _, newIndex in
						withAnimation {
							proxy.scrollTo(newIndex, anchor: .center)
						}
					}
					.onAppear {
						proxy.scrollTo(pdf.currentPageIndex, anchor: .center)
					}
				}
			} else {
				VStack {
					Spacer()
					Text("No PDF Open")
						.font(.caption)
						.foregroundStyle(.secondary)
					Spacer()
				}
			}
		}
		.accessibilityLabel("Page thumbnails")
	}

	private func thumbnailRow(doc: PDFDocument, index: Int) -> some View {
		Button {
			pdf.goToPage(index)
		} label: {
			VStack(spacing: 4) {
				if let page = doc.page(at: index) {
					PDFThumbnailView(page: page, size: thumbnailSize)
						.frame(width: thumbnailSize.width, height: thumbnailSize.height)
						.border(pdf.currentPageIndex == index ? Color.accentColor : Color.clear, width: 2)
						.shadow(color: .black.opacity(0.1), radius: 2)
				}
				Text("\(index + 1)")
					.font(.caption2)
					.foregroundStyle(pdf.currentPageIndex == index ? .primary : .secondary)
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Page \(index + 1)")
		.accessibilityAddTraits(pdf.currentPageIndex == index ? .isSelected : [])
	}
}

// MARK: - Thumbnail Renderer

struct PDFThumbnailView: NSViewRepresentable {
	let page: PDFPage
	let size: CGSize

	func makeNSView(context: Context) -> NSImageView {
		let imageView = NSImageView()
		imageView.imageScaling = .scaleProportionallyUpOrDown
		imageView.image = page.thumbnail(of: size, for: .mediaBox)
		return imageView
	}

	func updateNSView(_ nsView: NSImageView, context: Context) {
		nsView.image = page.thumbnail(of: size, for: .mediaBox)
	}
}
