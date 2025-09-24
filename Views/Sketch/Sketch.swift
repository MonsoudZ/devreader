import SwiftUI

final class SketchWindow: NSObject, NSWindowDelegate {
	private var window: NSWindow!
	private var onDone: (NSImage) -> Void
	private var size: CGSize
	
	init(size: CGSize, onDone: @escaping (NSImage) -> Void) {
		self.size = size; self.onDone = onDone
		super.init()
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "Sketch"
		window.center()
		let vc = NSHostingView(rootView: SketchView(size: size) { image in
			onDone(image); self.window.close()
		})
		window.contentView = vc
		window.delegate = self
	}
	
	func show() { window.makeKeyAndOrderFront(nil) }
}

struct SketchView: View {
	var size: CGSize
	var onInsert: (NSImage) -> Void
    struct Stroke: Identifiable { let id = UUID(); var path: Path; var color: Color; var lineWidth: CGFloat }
    @State private var strokes: [Stroke] = []
    @State private var current: Stroke = Stroke(path: Path(), color: .black, lineWidth: 2)
    @State private var penColor: Color = .black
    @State private var penWidth: CGFloat = 2
    @State private var canvasSize: CGSize = .zero
	
	var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Sketch")
                Divider()
                ColorPicker("Ink", selection: $penColor).labelsHidden()
                HStack { Text("Width"); Slider(value: $penWidth, in: 1...16, step: 1).frame(width: 140); Text("\(Int(penWidth))") }
                Divider()
                Button("Undo") { if !strokes.isEmpty { _ = strokes.removeLast() } }
                Button("Clear") { strokes.removeAll() }
                Spacer()
                Button("Insert") { let img = render(); onInsert(img) }
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
                .onAppear { canvasSize = sz }
                .onChange(of: sz) { newSize in canvasSize = newSize }
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
}
