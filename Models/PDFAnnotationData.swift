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

	nonisolated enum AnnotationType: String, Codable, Sendable {
		case highlight, underline
	}

	init(id: UUID = UUID(), pageIndex: Int, bounds: CodableRect, type: AnnotationType = .highlight, colorName: String, text: String? = nil, createdDate: Date = Date()) {
		self.id = id
		self.pageIndex = pageIndex
		self.bounds = bounds
		self.type = type
		self.colorName = colorName
		self.text = text
		self.createdDate = createdDate
	}
}
