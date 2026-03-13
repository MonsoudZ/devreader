import SwiftUI
import PDFKit

struct PDFThumbnailPane: View {
	@ObservedObject var pdf: PDFController
	private let thumbnailSize = CGSize(width: 120, height: 160)

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Pages").font(DS.Typography.heading)
				Spacer()
				Text("\(pdf.document?.pageCount ?? 0) pages")
					.font(DS.Typography.caption)
					.foregroundStyle(DS.Colors.secondary)
			}
			.padding(DS.Spacing.sm)
			Divider()

			if let doc = pdf.document {
				ScrollViewReader { proxy in
					ScrollView {
						LazyVStack(spacing: DS.Spacing.sm) {
							ForEach(0..<doc.pageCount, id: \.self) { index in
								thumbnailRow(doc: doc, index: index)
									.id(index)
							}
						}
						.padding(DS.Spacing.sm)
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
						.font(DS.Typography.caption)
						.foregroundStyle(DS.Colors.secondary)
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
			VStack(spacing: DS.Spacing.xs) {
				if let page = doc.page(at: index) {
					CachedThumbnailView(page: page, size: thumbnailSize, pageIndex: index)
						.frame(width: thumbnailSize.width, height: thumbnailSize.height)
						.clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
						.overlay(
							RoundedRectangle(cornerRadius: DS.Radius.sm)
								.strokeBorder(pdf.currentPageIndex == index ? DS.Colors.accent : Color.clear, lineWidth: 2)
						)
						.shadow(color: .black.opacity(0.1), radius: 2)
				}
				Text("\(index + 1)")
					.font(DS.Typography.caption2)
					.foregroundStyle(pdf.currentPageIndex == index ? DS.Colors.primary : DS.Colors.secondary)
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Page \(index + 1)")
		.accessibilityAddTraits(pdf.currentPageIndex == index ? .isSelected : [])
	}
}

// MARK: - Cached Thumbnail

/// Renders thumbnail once and caches the NSImage. Only re-renders if page identity changes.
struct CachedThumbnailView: NSViewRepresentable {
	let page: PDFPage
	let size: CGSize
	let pageIndex: Int

	func makeNSView(context: Context) -> NSImageView {
		let imageView = NSImageView()
		imageView.imageScaling = .scaleProportionallyUpOrDown
		imageView.image = context.coordinator.cachedImage(for: page, size: size)
		return imageView
	}

	func updateNSView(_ nsView: NSImageView, context: Context) {
		nsView.image = context.coordinator.cachedImage(for: page, size: size)
	}

	func makeCoordinator() -> ThumbnailCoordinator {
		ThumbnailCoordinator()
	}

	final class ThumbnailCoordinator {
		private var cache: [ObjectIdentifier: NSImage] = [:]

		func cachedImage(for page: PDFPage, size: CGSize) -> NSImage {
			let key = ObjectIdentifier(page)
			if let cached = cache[key] { return cached }
			let image = page.thumbnail(of: size, for: .mediaBox)
			cache[key] = image
			return image
		}
	}
}
