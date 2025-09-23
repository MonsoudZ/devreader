import Foundation
import PDFKit
import SwiftUI

extension PDFSelection {
	func pageBoxes() -> [(PDFPage, CGRect)] {
		var res: [(PDFPage, CGRect)] = []
		for page in pages {
			let bounds = bounds(for: page)
			if !bounds.isEmpty { res.append((page, bounds)) }
		}
		return res
	}
}

extension Path {
	func nsBezierPath() -> NSBezierPath {
		let bp = NSBezierPath()
		var first = true
		self.forEach { element in
			switch element {
			case .move(to: let p):
				bp.move(to: NSPoint(x: p.x, y: p.y)); first = false
			case .line(to: let p):
				if first { bp.move(to: NSPoint(x: p.x, y: p.y)); first = false } else { bp.line(to: NSPoint(x: p.x, y: p.y)) }
			case .quadCurve(to: let p, control: let c):
				bp.curve(to: NSPoint(x: p.x, y: p.y), controlPoint1: NSPoint(x: c.x, y: c.y), controlPoint2: NSPoint(x: c.x, y: c.y))
			case .curve(to: let p, control1: let c1, control2: let c2):
				bp.curve(to: NSPoint(x: p.x, y: p.y), controlPoint1: NSPoint(x: c1.x, y: c1.y), controlPoint2: NSPoint(x: c2.x, y: c2.y))
			case .closeSubpath:
				bp.close()
			@unknown default: break
			}
		}
		return bp
	}
}

extension Notification.Name {
	static let captureHighlight = Notification.Name("DevReader.captureHighlight")
	static let newSketchPage    = Notification.Name("DevReader.newSketchPage")
	static let addStickyNote    = Notification.Name("DevReader.addStickyNote")
	static let closePDF         = Notification.Name("DevReader.closePDF")
}
