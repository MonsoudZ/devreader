import SwiftUI
import AppKit

/// A two-tab pad for drawing or typing a signature. Returns an NSImage on apply.
struct SignaturePadView: View {
	var onApply: (NSImage, Bool) -> Void  // (image, saveForReuse)
	var onCancel: () -> Void

	private enum Tab: String, CaseIterable {
		case draw = "Draw"
		case type = "Type"
	}

	@State private var selectedTab: Tab = .draw

	// Draw state
	@State private var strokes: [[CGPoint]] = []
	@State private var currentStroke: [CGPoint] = []

	// Type state
	@State private var typedName: String = ""
	@State private var selectedFont: String = "Snell Roundhand"
	private let cursiveFonts = ["Snell Roundhand", "Bradley Hand", "Zapfino", "Noteworthy"]

	// Shared
	@State private var saveForReuse = false

	private let canvasWidth: CGFloat = 400
	private let canvasHeight: CGFloat = 200

	var body: some View {
		VStack(spacing: 0) {
			Text("Signature")
				.font(.headline)
				.padding(.top, 12)

			Picker("Mode", selection: $selectedTab) {
				ForEach(Tab.allCases, id: \.self) { tab in
					Text(tab.rawValue).tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.padding(.horizontal, 24)
			.padding(.top, 8)

			Group {
				switch selectedTab {
				case .draw:
					drawTabContent
				case .type:
					typeTabContent
				}
			}
			.padding(.horizontal, 24)
			.padding(.top, 12)

			Toggle("Save for Reuse", isOn: $saveForReuse)
				.padding(.horizontal, 24)
				.padding(.top, 8)

			HStack {
				Button("Cancel") { onCancel() }
					.keyboardShortcut(.cancelAction)
				Spacer()
				Button("Apply") { applySignature() }
					.keyboardShortcut(.defaultAction)
					.disabled(!canApply)
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 12)
		}
		.frame(width: 460)
	}

	// MARK: - Draw Tab

	private var drawTabContent: some View {
		VStack(spacing: 8) {
			ZStack {
				RoundedRectangle(cornerRadius: 8)
					.fill(Color.white)
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(Color.gray.opacity(0.4), lineWidth: 1)
					)

				Canvas { context, _ in
					for stroke in strokes {
						drawStrokePath(stroke, in: &context)
					}
					if !currentStroke.isEmpty {
						drawStrokePath(currentStroke, in: &context)
					}
				}
				.gesture(
					DragGesture(minimumDistance: 0)
						.onChanged { value in
							let point = value.location
							guard point.x >= 0, point.x <= canvasWidth,
								  point.y >= 0, point.y <= canvasHeight else { return }
							currentStroke.append(point)
						}
						.onEnded { _ in
							if !currentStroke.isEmpty {
								strokes.append(currentStroke)
								currentStroke = []
							}
						}
				)
			}
			.frame(width: canvasWidth, height: canvasHeight)

			HStack {
				Button("Undo") {
					if !strokes.isEmpty { strokes.removeLast() }
				}
				.disabled(strokes.isEmpty)

				Button("Clear") {
					strokes.removeAll()
					currentStroke.removeAll()
				}
				.disabled(strokes.isEmpty && currentStroke.isEmpty)

				Spacer()
			}
		}
	}

	private func drawStrokePath(_ points: [CGPoint], in context: inout GraphicsContext) {
		guard points.count > 1 else { return }
		var path = Path()
		path.move(to: points[0])
		for i in 1..<points.count {
			path.addLine(to: points[i])
		}
		context.stroke(path, with: .color(.black), lineWidth: 2)
	}

	// MARK: - Type Tab

	private var typeTabContent: some View {
		VStack(spacing: 12) {
			TextField("Your name", text: $typedName)
				.textFieldStyle(.roundedBorder)

			Picker("Font", selection: $selectedFont) {
				ForEach(cursiveFonts, id: \.self) { font in
					Text(font).tag(font)
				}
			}

			// Live preview
			ZStack {
				RoundedRectangle(cornerRadius: 8)
					.fill(Color.white)
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(Color.gray.opacity(0.4), lineWidth: 1)
					)

				Text(typedName.isEmpty ? "Preview" : typedName)
					.font(.custom(selectedFont, size: 36))
					.foregroundColor(typedName.isEmpty ? .gray.opacity(0.4) : .black)
					.lineLimit(1)
					.minimumScaleFactor(0.5)
					.padding(.horizontal, 12)
			}
			.frame(width: canvasWidth, height: 80)
		}
	}

	// MARK: - Helpers

	private var canApply: Bool {
		switch selectedTab {
		case .draw: return !strokes.isEmpty
		case .type: return !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
	}

	private func applySignature() {
		let image: NSImage
		switch selectedTab {
		case .draw:
			image = renderDrawnSignature()
		case .type:
			image = renderTypedSignature()
		}
		onApply(image, saveForReuse)
	}

	private func renderDrawnSignature() -> NSImage {
		let img = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))
		img.lockFocus()

		NSColor.clear.set()
		NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()

		let path = NSBezierPath()
		path.lineWidth = 2
		NSColor.black.setStroke()

		for stroke in strokes {
			guard let first = stroke.first else { continue }
			// Flip Y because NSImage drawing is bottom-up
			path.move(to: NSPoint(x: first.x, y: canvasHeight - first.y))
			for i in 1..<stroke.count {
				path.line(to: NSPoint(x: stroke[i].x, y: canvasHeight - stroke[i].y))
			}
		}
		path.stroke()
		img.unlockFocus()

		return trimmedImage(img)
	}

	private func renderTypedSignature() -> NSImage {
		let text = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
		let font = NSFont(name: selectedFont, size: 48) ?? NSFont.systemFont(ofSize: 48)
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: NSColor.black
		]
		let attrString = NSAttributedString(string: text, attributes: attributes)
		let size = attrString.size()

		let padding: CGFloat = 16
		let imageSize = NSSize(width: size.width + padding * 2, height: size.height + padding * 2)
		let img = NSImage(size: imageSize)
		img.lockFocus()
		NSColor.clear.set()
		NSRect(origin: .zero, size: imageSize).fill()
		attrString.draw(at: NSPoint(x: padding, y: padding))
		img.unlockFocus()

		return img
	}

	/// Trims transparent pixels from the edges of the signature image.
	private func trimmedImage(_ source: NSImage) -> NSImage {
		guard let tiffData = source.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData),
			  let cgImage = bitmap.cgImage else { return source }

		let width = cgImage.width
		let height = cgImage.height
		guard width > 0, height > 0 else { return source }

		guard let context = CGContext(
			data: nil, width: width, height: height,
			bitsPerComponent: 8, bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return source }

		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		guard let data = context.data else { return source }
		let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

		var minX = width, minY = height, maxX = 0, maxY = 0
		for y in 0..<height {
			for x in 0..<width {
				let alpha = pixels[(y * width + x) * 4 + 3]
				if alpha > 0 {
					minX = min(minX, x)
					minY = min(minY, y)
					maxX = max(maxX, x)
					maxY = max(maxY, y)
				}
			}
		}

		guard maxX >= minX, maxY >= minY else { return source }
		let padding = 4
		let cropRect = CGRect(
			x: max(0, minX - padding),
			y: max(0, minY - padding),
			width: min(width, maxX - minX + 1 + padding * 2),
			height: min(height, maxY - minY + 1 + padding * 2)
		)

		guard let cropped = cgImage.cropping(to: cropRect) else { return source }
		return NSImage(cgImage: cropped, size: NSSize(width: cropRect.width, height: cropRect.height))
	}
}
