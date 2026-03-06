import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import os.log

final class SketchWindow: NSObject, NSWindowDelegate {
	private var window: NSWindow!
	private var onDone: (NSImage) -> Void
	private var size: CGSize
	private var pdfURL: URL?
	private var pageIndex: Int

	init(size: CGSize, pdfURL: URL? = nil, pageIndex: Int = 0, sketchStore: SketchStore? = nil, onDone: @escaping (NSImage) -> Void) {
		self.size = size
		self.pdfURL = pdfURL
		self.pageIndex = pageIndex
		self.onDone = onDone
		super.init()
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "Sketch"
		window.center()
		let vc = NSHostingView(rootView: SketchView(
			size: size,
			onInsert: { [weak self] image in
				onDone(image)
				self?.window.close()
			},
			pdfURL: pdfURL,
			pageIndex: pageIndex,
			sketchStore: sketchStore
		))
		window.contentView = vc
		window.delegate = self
	}

	func show() { window.makeKeyAndOrderFront(nil) }
}

struct SketchView: View {
	var size: CGSize
	var onInsert: (NSImage) -> Void
	var pdfURL: URL? = nil
	var pageIndex: Int = 0

	struct Stroke: Identifiable, Codable {
		let id: UUID
		var path: Path
		var color: Color
		var lineWidth: CGFloat

		private enum PathCommand: Codable {
			case move(x: CGFloat, y: CGFloat)
			case line(x: CGFloat, y: CGFloat)
			case quadCurve(toX: CGFloat, toY: CGFloat, controlX: CGFloat, controlY: CGFloat)
			case curve(toX: CGFloat, toY: CGFloat, c1X: CGFloat, c1Y: CGFloat, c2X: CGFloat, c2Y: CGFloat)
			case closeSubpath
		}

		enum CodingKeys: String, CodingKey {
			case id, pathData, colorData, lineWidth
		}

		init(path: Path, color: Color, lineWidth: CGFloat) {
			self.id = UUID()
			self.path = path
			self.color = color
			self.lineWidth = lineWidth
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decode(UUID.self, forKey: .id)
			lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)

			let pathData = try container.decode(Data.self, forKey: .pathData)
			let commands = try JSONDecoder().decode([PathCommand].self, from: pathData)
			var decodedPath = Path()
			for cmd in commands {
				switch cmd {
				case .move(let x, let y):
					decodedPath.move(to: CGPoint(x: x, y: y))
				case .line(let x, let y):
					decodedPath.addLine(to: CGPoint(x: x, y: y))
				case .quadCurve(let toX, let toY, let cx, let cy):
					decodedPath.addQuadCurve(to: CGPoint(x: toX, y: toY), control: CGPoint(x: cx, y: cy))
				case .curve(let toX, let toY, let c1X, let c1Y, let c2X, let c2Y):
					decodedPath.addCurve(to: CGPoint(x: toX, y: toY), control1: CGPoint(x: c1X, y: c1Y), control2: CGPoint(x: c2X, y: c2Y))
				case .closeSubpath:
					decodedPath.closeSubpath()
				}
			}
			path = decodedPath

			let colorData = try container.decode(Data.self, forKey: .colorData)
			let components = try JSONDecoder().decode([CGFloat].self, from: colorData)
			if components.count == 4 {
				color = Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
			} else {
				logError(AppLog.sketch, "Invalid color data: expected 4 components, got \(components.count)")
				color = Color.black
			}
		}

		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(id, forKey: .id)
			try container.encode(lineWidth, forKey: .lineWidth)

			// Encode path elements directly to the keyed container via Data
			let pathData: Data = try {
				var commands: [PathCommand] = []
				path.forEach { element in
					switch element {
					case .move(to: let p):
						commands.append(.move(x: p.x, y: p.y))
					case .line(to: let p):
						commands.append(.line(x: p.x, y: p.y))
					case .quadCurve(to: let p, control: let c):
						commands.append(.quadCurve(toX: p.x, toY: p.y, controlX: c.x, controlY: c.y))
					case .curve(to: let p, control1: let c1, control2: let c2):
						commands.append(.curve(toX: p.x, toY: p.y, c1X: c1.x, c1Y: c1.y, c2X: c2.x, c2Y: c2.y))
					case .closeSubpath:
						commands.append(.closeSubpath)
					}
				}
				return try JSONEncoder().encode(commands)
			}()
			try container.encode(pathData, forKey: .pathData)

			guard let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.black.usingColorSpace(.deviceRGB) else {
				try container.encode(Data(), forKey: .colorData)
				return
			}
			let components: [CGFloat] = [nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent, nsColor.alphaComponent]
			let colorData = try JSONEncoder().encode(components)
			try container.encode(colorData, forKey: .colorData)
		}
	}

	enum SketchTool: String, CaseIterable {
		case pen, eraser, rectangle, circle, line

		var icon: String {
			switch self {
			case .pen: "pencil"
			case .eraser: "eraser"
			case .rectangle: "rectangle"
			case .circle: "circle"
			case .line: "line.diagonal"
			}
		}

		var label: String {
			switch self {
			case .pen: "Pen"
			case .eraser: "Eraser"
			case .rectangle: "Rectangle"
			case .circle: "Circle"
			case .line: "Line"
			}
		}
	}

	@State private var strokes: [Stroke] = []
	@State private var current: Stroke = Stroke(path: Path(), color: .black, lineWidth: 2)
	@State private var penColor: Color = .black
	@State private var penWidth: CGFloat = 2
	@State private var canvasSize: CGSize = .zero
	@State private var activeTool: SketchTool = .pen
	@State private var dragStart: CGPoint = .zero

	// Undo/Redo stacks
	@State private var undoStack: [[Stroke]] = []
	@State private var redoStack: [[Stroke]] = []

	// Persistence — use shared store from AppEnvironment for lifecycle flush support
	@ObservedObject private var sketchStore: SketchStore

	init(size: CGSize, onInsert: @escaping (NSImage) -> Void, pdfURL: URL? = nil, pageIndex: Int = 0, sketchStore: SketchStore? = nil) {
		self.size = size
		self.onInsert = onInsert
		self.pdfURL = pdfURL
		self.pageIndex = pageIndex
		self._sketchStore = ObservedObject(wrappedValue: sketchStore ?? SketchStore())
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 12) {
				Text("Sketch")
				Divider()

				// Tool picker
				ForEach(SketchTool.allCases, id: \.self) { tool in
					Button {
						activeTool = tool
					} label: {
						Image(systemName: tool.icon)
					}
					.buttonStyle(.borderless)
					.foregroundColor(activeTool == tool ? .accentColor : .secondary)
					.help(tool.label)
					.accessibilityLabel(tool.label)
				}

				Divider()
				ColorPicker("Ink", selection: $penColor)
					.labelsHidden()
					.accessibilityIdentifier("sketchColorPicker")
					.accessibilityLabel("Pen Color")
					.accessibilityHint("Choose the color for drawing strokes")
				HStack {
					Text("Width")
					Slider(value: $penWidth, in: 1...16, step: 1)
						.frame(width: 140)
						.accessibilityIdentifier("sketchWidthSlider")
						.accessibilityLabel("Pen Width")
						.accessibilityValue("\(Int(penWidth)) pixels")
					Text("\(Int(penWidth))")
				}
				Divider()
				Button("Undo") { undo() }
					.accessibilityIdentifier("sketchUndo")
					.accessibilityLabel("Undo Last Stroke")
					.accessibilityHint("Remove the most recent drawing stroke")
					.disabled(strokes.isEmpty && undoStack.isEmpty)
				Button("Redo") { redo() }
					.accessibilityIdentifier("sketchRedo")
					.accessibilityLabel("Redo Stroke")
					.accessibilityHint("Restore the most recently undone stroke")
					.disabled(redoStack.isEmpty)
				Button("Clear") { clearAll() }
					.accessibilityIdentifier("sketchClear")
					.accessibilityLabel("Clear All Strokes")
					.accessibilityHint("Remove all drawing strokes from the canvas")
					.disabled(strokes.isEmpty)
				Spacer()
				Menu("Export") {
					Button("Save as PNG") {
						SketchRenderService.exportAsPNG(image: renderImage())
					}
					Button("Save as PDF") {
						SketchRenderService.exportAsPDF(image: renderImage())
					}
					Button("Save to PDF Page") { saveToPDFPage() }
				}
				.accessibilityIdentifier("sketchExportMenu")
				.accessibilityLabel("Export Options")
				.accessibilityHint("Save the sketch as an image file")
				Button("Insert") {
					let img = renderImage()
					onInsert(img)
					saveSketch()
				}
				.accessibilityIdentifier("sketchInsert")
				.accessibilityLabel("Insert Sketch")
				.accessibilityHint("Insert the sketch into the current document")
			}.padding(8)
			Divider()
			GeometryReader { proxy in
				let sz = proxy.size
				ZStack(alignment: .topLeading) {
					Color.white
					ForEach(strokes) { s in s.path.stroke(s.color, lineWidth: s.lineWidth) }
					current.path.stroke(current.color, lineWidth: current.lineWidth)
				}
				.contentShape(Rectangle())
				.gesture(DragGesture(minimumDistance: 0)
					.onChanged { value in
						switch activeTool {
						case .pen:
							if current.path.isEmpty {
								current = Stroke(path: Path(), color: penColor, lineWidth: penWidth)
								current.path.move(to: value.location)
							} else {
								current.path.addLine(to: value.location)
							}
						case .eraser:
							// Remove strokes whose bounding box contains the drag point
							strokes.removeAll { stroke in
								stroke.path.boundingRect.insetBy(dx: -stroke.lineWidth, dy: -stroke.lineWidth).contains(value.location)
							}
						case .rectangle, .circle, .line:
							if dragStart == .zero { dragStart = value.startLocation }
							var shapePath = Path()
							let rect = CGRect(
								x: min(dragStart.x, value.location.x),
								y: min(dragStart.y, value.location.y),
								width: abs(value.location.x - dragStart.x),
								height: abs(value.location.y - dragStart.y)
							)
							switch activeTool {
							case .rectangle: shapePath.addRect(rect)
							case .circle: shapePath.addEllipse(in: rect)
							case .line:
								shapePath.move(to: dragStart)
								shapePath.addLine(to: value.location)
							default: break
							}
							current = Stroke(path: shapePath, color: penColor, lineWidth: penWidth)
						}
					}
					.onEnded { _ in
						if activeTool == .eraser {
							return
						}
						if !current.path.isEmpty {
							strokes.append(current)
						}
						current = Stroke(path: Path(), color: penColor, lineWidth: penWidth)
						dragStart = .zero
					}
				)
				.onAppear {
					canvasSize = sz
					loadSketch()
				}
				.onChange(of: sz) { _, newSize in
					scaleStrokesToNewSize(newSize)
					canvasSize = newSize
				}
			}
		}
		.frame(minWidth: size.width * 0.7, minHeight: size.height * 0.7)
	}

	// MARK: - Rendering (delegates to service)

	private func renderImage() -> NSImage {
		SketchRenderService.render(strokes: strokes, canvasSize: canvasSize, fallbackSize: size)
	}

	// MARK: - Undo/Redo

	private func undo() {
		guard !strokes.isEmpty || !undoStack.isEmpty else { return }
		redoStack.append(strokes)
		if !strokes.isEmpty {
			strokes.removeLast()
		} else if !undoStack.isEmpty {
			strokes = undoStack.removeLast()
		}
	}

	private func redo() {
		guard !redoStack.isEmpty else { return }
		undoStack.append(strokes)
		strokes = redoStack.removeLast()
	}

	private func clearAll() {
		undoStack.append(strokes)
		redoStack.removeAll()
		strokes.removeAll()
	}

	// MARK: - Persistence (delegates to service)

	private func saveSketch() {
		guard let pdfURL = pdfURL else { return }
		SketchRenderService.saveSketch(
			strokes: strokes,
			canvasSize: canvasSize,
			fallbackSize: size,
			pdfURL: pdfURL,
			pageIndex: pageIndex,
			sketchStore: sketchStore
		)
	}

	private func loadSketch() {
		guard let pdfURL = pdfURL else { return }
		if let loaded = SketchRenderService.loadStrokes(pdfURL: pdfURL, pageIndex: pageIndex, sketchStore: sketchStore) {
			strokes = loaded
		}
	}

	// MARK: - Window Resizing

	private func scaleStrokesToNewSize(_ newSize: CGSize) {
		guard canvasSize != .zero && newSize != canvasSize else { return }
		let scaleX = newSize.width / canvasSize.width
		let scaleY = newSize.height / canvasSize.height
		let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
		for i in strokes.indices {
			strokes[i].path = strokes[i].path.applying(transform)
			strokes[i].lineWidth *= min(scaleX, scaleY)
		}
	}

	private func saveToPDFPage() {
		guard pdfURL != nil else { return }
		saveSketch()
	}
}
