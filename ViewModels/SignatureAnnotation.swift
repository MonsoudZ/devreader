@preconcurrency import PDFKit
import AppKit

/// Custom PDFAnnotation subclass that draws an NSImage as a signature overlay on a PDF page.
/// Must be nonisolated because PDFAnnotation's designated initializer and draw(with:in:)
/// are nonisolated, and the project uses SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
nonisolated final class SignatureAnnotation: PDFAnnotation {
	nonisolated(unsafe) var signatureImage: NSImage?

	override init(bounds: CGRect, forType type: PDFAnnotationSubtype?, withProperties properties: [AnyHashable: Any]?) {
		super.init(bounds: bounds, forType: type ?? .stamp, withProperties: properties)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	/// Convenience factory called from MainActor context.
	@MainActor
	static func make(bounds: CGRect, image: NSImage) -> SignatureAnnotation {
		let annotation = SignatureAnnotation(bounds: bounds, forType: .stamp, withProperties: nil)
		annotation.signatureImage = image
		return annotation
	}

	override func draw(with box: PDFDisplayBox, in context: CGContext) {
		context.saveGState()

		guard let img = signatureImage,
			  let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			context.restoreGState()
			return
		}

		context.draw(cgImage, in: bounds)
		context.restoreGState()
	}
}
