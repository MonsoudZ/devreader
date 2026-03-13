import Foundation
import CoreGraphics

nonisolated struct CodableRect: Codable, Hashable, Sendable {
	let x, y, width, height: Double

	init(from cgRect: CGRect) {
		self.x = Double(cgRect.origin.x)
		self.y = Double(cgRect.origin.y)
		self.width = Double(cgRect.size.width)
		self.height = Double(cgRect.size.height)
	}

	var cgRect: CGRect {
		CGRect(x: x, y: y, width: width, height: height)
	}
}

nonisolated struct PDFAnnotationData: Codable, Identifiable, Hashable, Sendable {
	let id: UUID
	let pageIndex: Int
	let bounds: CodableRect
	let type: AnnotationType
	let colorName: String     // "yellow", "green", "blue", "pink"
	let text: String?         // selected text (for display)
	let createdDate: Date
	let signatureImageData: Data?  // PNG data for signature annotations (nil for others)

	nonisolated enum AnnotationType: String, Codable, Sendable {
		case highlight, underline, strikethrough, signature
	}

	init(id: UUID = UUID(), pageIndex: Int, bounds: CodableRect, type: AnnotationType = .highlight, colorName: String, text: String? = nil, createdDate: Date = Date(), signatureImageData: Data? = nil) {
		self.id = id
		self.pageIndex = pageIndex
		self.bounds = bounds
		self.type = type
		self.colorName = colorName
		self.text = text
		self.createdDate = createdDate
		self.signatureImageData = signatureImageData
	}

	// Custom decoding for backward compatibility — older data won't have signatureImageData
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		pageIndex = try container.decode(Int.self, forKey: .pageIndex)
		bounds = try container.decode(CodableRect.self, forKey: .bounds)
		type = try container.decode(AnnotationType.self, forKey: .type)
		colorName = try container.decode(String.self, forKey: .colorName)
		text = try container.decodeIfPresent(String.self, forKey: .text)
		createdDate = try container.decode(Date.self, forKey: .createdDate)
		signatureImageData = try container.decodeIfPresent(Data.self, forKey: .signatureImageData)
	}
}
