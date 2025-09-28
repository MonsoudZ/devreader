import SwiftUI
import PDFKit
import UniformTypeIdentifiers

final class SketchWindow: NSObject, NSWindowDelegate {
	private var window: NSWindow!
	private var onDone: (NSImage) -> Void
	private var size: CGSize
	private var pdfURL: URL?
	private var pageIndex: Int
	
	init(size: CGSize, pdfURL: URL? = nil, pageIndex: Int = 0, onDone: @escaping (NSImage) -> Void) {
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
			onInsert: { image in
				onDone(image)
				self.window.close()
			},
			pdfURL: pdfURL,
			pageIndex: pageIndex
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
		let id = UUID()
		var path: Path
		var color: Color
		var lineWidth: CGFloat
		
		// Custom coding for Path and Color
		enum CodingKeys: String, CodingKey {
			case id, pathData, colorData, lineWidth
		}
		
		init(path: Path, color: Color, lineWidth: CGFloat) {
			self.path = path
			self.color = color
			self.lineWidth = lineWidth
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let _ = try container.decode(Data.self, forKey: .pathData)
			let _ = try container.decode(Data.self, forKey: .colorData)
			lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
			
			// Reconstruct Path and Color from data
			path = Path()
			color = Color.black
		}
		
		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(Data(), forKey: .pathData) // Simplified for now
			try container.encode(Data(), forKey: .colorData)
			try container.encode(lineWidth, forKey: .lineWidth)
		}
	}
	
    @State private var strokes: [Stroke] = []
    @State private var current: Stroke = Stroke(path: Path(), color: .black, lineWidth: 2)
    @State private var penColor: Color = .black
    @State private var penWidth: CGFloat = 2
    @State private var canvasSize: CGSize = .zero
	
	// Undo/Redo stacks
	@State private var undoStack: [[Stroke]] = []
	@State private var redoStack: [[Stroke]] = []
	
	// Persistence
	@StateObject private var sketchStore = SketchStore()
	
	var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Sketch")
                Divider()
                ColorPicker("Ink", selection: $penColor)
                    .labelsHidden()
                    .accessibilityLabel("Pen Color")
                    .accessibilityHint("Choose the color for drawing strokes")
                HStack { 
                    Text("Width")
                    Slider(value: $penWidth, in: 1...16, step: 1)
                        .frame(width: 140)
                        .accessibilityLabel("Pen Width")
                        .accessibilityValue("\(Int(penWidth)) pixels")
                    Text("\(Int(penWidth))") 
                }
                Divider()
                Button("Undo") { undo() }
                    .accessibilityLabel("Undo Last Stroke")
                    .accessibilityHint("Remove the most recent drawing stroke")
                    .disabled(strokes.isEmpty && undoStack.isEmpty)
                Button("Redo") { redo() }
                    .accessibilityLabel("Redo Stroke")
                    .accessibilityHint("Restore the most recently undone stroke")
                    .disabled(redoStack.isEmpty)
                Button("Clear") { clearAll() }
                    .accessibilityLabel("Clear All Strokes")
                    .accessibilityHint("Remove all drawing strokes from the canvas")
                    .disabled(strokes.isEmpty)
                Spacer()
                Menu("Export") {
                    Button("Save as PNG") { exportAsPNG() }
                    Button("Save as PDF") { exportAsPDF() }
                    Button("Save to PDF Page") { saveToPDFPage() }
                }
                .accessibilityLabel("Export Options")
                .accessibilityHint("Save the sketch as an image file")
                Button("Insert") { 
                    let img = render()
                    onInsert(img)
                    saveSketch()
                }
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
                        if current.path.isEmpty {
                            current = Stroke(path: Path(), color: penColor, lineWidth: penWidth)
                            current.path.move(to: value.location)
                        } else {
                            current.path.addLine(to: value.location)
                        }
                    }
                    .onEnded { _ in
                        strokes.append(current)
                        current = Stroke(path: Path(), color: penColor, lineWidth: penWidth)
                    }
                )
                .onAppear { 
                    canvasSize = sz
                    loadSketch()
                }
                .onChange(of: sz) { _, newSize in 
                    canvasSize = newSize
                    // Scale strokes to new size if needed
                    scaleStrokesToNewSize(newSize)
                }
            }
        }
        .frame(minWidth: size.width * 0.7, minHeight: size.height * 0.7)
	}
	
	func render() -> NSImage {
        let targetSize = canvasSize == .zero ? size : canvasSize
        let rect = CGRect(origin: .zero, size: targetSize)
        let img = NSImage(size: targetSize)
		img.lockFocus()
		NSColor.white.setFill(); rect.fill()
        for s in strokes {
            let nsPath = s.path.nsBezierPath()
            nsPath.lineWidth = s.lineWidth
            NSColor(s.color).setStroke()
            nsPath.stroke()
        }
		img.unlockFocus(); return img
	}
	
	// MARK: - Undo/Redo Methods
	
	private func undo() {
		guard !strokes.isEmpty || !undoStack.isEmpty else { return }
		
		// Save current state to redo stack
		redoStack.append(strokes)
		
		if !strokes.isEmpty {
			// Remove last stroke
			strokes.removeLast()
		} else if !undoStack.isEmpty {
			// Restore from undo stack
			strokes = undoStack.removeLast()
		}
	}
	
	private func redo() {
		guard !redoStack.isEmpty else { return }
		
		// Save current state to undo stack
		undoStack.append(strokes)
		
		// Restore from redo stack
		strokes = redoStack.removeLast()
	}
	
	private func clearAll() {
		// Save current state to undo stack
		undoStack.append(strokes)
		redoStack.removeAll()
		strokes.removeAll()
	}
	
	// MARK: - Persistence Methods
	
	private func saveSketch() {
		guard let pdfURL = pdfURL else { return }
		
		// Create sketch using the store's method
		// The store will handle the SketchItem creation
		
		sketchStore.createSketch(for: pdfURL, pageIndex: pageIndex)
	}
	
	private func loadSketch() {
		// Load sketches from the store
		// Note: This is a simplified implementation
		// In a full implementation, you'd reconstruct strokes from the image data
	}
	
	// MARK: - Window Resizing Support
	
	private func scaleStrokesToNewSize(_ newSize: CGSize) {
		guard canvasSize != .zero && newSize != canvasSize else { return }
		
		let scaleX = newSize.width / canvasSize.width
		let scaleY = newSize.height / canvasSize.height
		
		// Scale all strokes to match new canvas size
		for i in strokes.indices {
			// This is a simplified approach - in practice you'd need to
			// transform the Path points based on the scale factors
			strokes[i].lineWidth *= min(scaleX, scaleY)
		}
	}
	
	// MARK: - Export Methods
	
	private func exportAsPNG() {
		let image = render()
		let savePanel = NSSavePanel()
		savePanel.allowedContentTypes = [.png]
		savePanel.nameFieldStringValue = "Sketch.png"
		
		savePanel.begin { response in
			if response == .OK, let url = savePanel.url {
				if let tiffData = image.tiffRepresentation,
				   let bitmapRep = NSBitmapImageRep(data: tiffData),
				   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
					try? pngData.write(to: url)
				}
			}
		}
	}
	
	private func exportAsPDF() {
		let image = render()
		let savePanel = NSSavePanel()
		savePanel.allowedContentTypes = [.pdf]
		savePanel.nameFieldStringValue = "Sketch.pdf"
		
		savePanel.begin { response in
			if response == .OK, let url = savePanel.url {
				let pdfDocument = PDFDocument()
				if let pdfPage = PDFPage(image: image) {
					pdfDocument.insert(pdfPage, at: 0)
					pdfDocument.write(to: url)
				}
			}
		}
	}
	
	private func saveToPDFPage() {
		guard pdfURL != nil else { return }
		
		// This would integrate with the PDF annotation system
		// For now, just save as a sketch item
		saveSketch()
	}
}

