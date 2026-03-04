import Foundation
import AppKit
@preconcurrency import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import os.log

/// Rendering and export operations for sketch strokes, extracted from SketchView.
enum SketchRenderService {
	/// Renders strokes to an NSImage on a white background.
	static func render(strokes: [SketchView.Stroke], canvasSize: CGSize, fallbackSize: CGSize) -> NSImage {
		let targetSize = canvasSize == .zero ? fallbackSize : canvasSize
		let rect = CGRect(origin: .zero, size: targetSize)
		let img = NSImage(size: targetSize)
		img.lockFocus()
		NSColor.white.setFill()
		rect.fill()
		for s in strokes {
			let nsPath = s.path.nsBezierPath()
			nsPath.lineWidth = s.lineWidth
			NSColor(s.color).setStroke()
			nsPath.stroke()
		}
		img.unlockFocus()
		return img
	}

	// MARK: - Persistence

	/// Encodes strokes and saves them along with a rendered image to the SketchStore.
	static func saveSketch(
		strokes: [SketchView.Stroke],
		canvasSize: CGSize,
		fallbackSize: CGSize,
		pdfURL: URL,
		pageIndex: Int,
		sketchStore: SketchStore
	) {
		let strokesData: Data?
		do {
			strokesData = try JSONEncoder().encode(strokes)
		} catch {
			logError(AppLog.sketch, "Failed to encode sketch strokes: \(error.localizedDescription)")
			strokesData = nil
		}

		let image = render(strokes: strokes, canvasSize: canvasSize, fallbackSize: fallbackSize)
		let canvasData = image.tiffRepresentation ?? Data()

		sketchStore.createSketch(for: pdfURL, pageIndex: pageIndex, canvasData: canvasData, strokesData: strokesData)
	}

	/// Loads strokes from the most recent sketch for this PDF page.
	static func loadStrokes(pdfURL: URL, pageIndex: Int, sketchStore: SketchStore) -> [SketchView.Stroke]? {
		let existing = sketchStore.getSketches(for: pdfURL, pageIndex: pageIndex)
		guard let latest = existing.last, let data = latest.strokesData else { return nil }
		return try? JSONDecoder().decode([SketchView.Stroke].self, from: data)
	}

	// MARK: - Export

	/// Exports an image as PNG to a user-chosen file via NSSavePanel.
	static func exportAsPNG(image: NSImage) {
		let savePanel = NSSavePanel()
		savePanel.allowedContentTypes = [.png]
		savePanel.nameFieldStringValue = "Sketch.png"

		savePanel.begin { response in
			guard response == .OK, let url = savePanel.url else { return }
			do {
				guard let tiffData = image.tiffRepresentation,
					  let bitmapRep = NSBitmapImageRep(data: tiffData),
					  let pngData = bitmapRep.representation(using: .png, properties: [:])
				else { return }
				try pngData.write(to: url)
			} catch {
				logError(AppLog.sketch, "Failed to export PNG: \(error.localizedDescription)")
			}
		}
	}

	/// Exports an image as a single-page PDF to a user-chosen file via NSSavePanel.
	static func exportAsPDF(image: NSImage) {
		let savePanel = NSSavePanel()
		savePanel.allowedContentTypes = [.pdf]
		savePanel.nameFieldStringValue = "Sketch.pdf"

		savePanel.begin { response in
			guard response == .OK, let url = savePanel.url else { return }
			let pdfDocument = PDFDocument()
			if let pdfPage = PDFPage(image: image) {
				pdfDocument.insert(pdfPage, at: 0)
				if !pdfDocument.write(to: url) {
					logError(AppLog.sketch, "Failed to write PDF to \(url.lastPathComponent)")
				}
			}
		}
	}
}
