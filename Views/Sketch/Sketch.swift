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
	@State private var paths: [Path] = []
	@State private var current: Path = Path()
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Draw freehand. Click Insert when done.")
				Spacer()
				Button("Clear") { paths.removeAll() }
				Button("Insert") { let img = render(); onInsert(img) }
			}.padding(8)
			Divider()
			GeometryReader { _ in
				ZStack {
					Color.white
					ForEach(paths.indices, id: \.self) { i in paths[i].stroke(lineWidth: 2) }
					current.stroke(lineWidth: 2)
				}
				.gesture(DragGesture(minimumDistance: 0)
					.onChanged { value in if current.isEmpty { current.move(to: value.location) } else { current.addLine(to: value.location) } }
					.onEnded { _ in paths.append(current); current = Path() }
				)
			}
		}
		.frame(minWidth: size.width * 0.7, minHeight: size.height * 0.7)
	}
	
	func render() -> NSImage {
		let rect = CGRect(origin: .zero, size: size)
		let img = NSImage(size: size)
		img.lockFocus()
		NSColor.white.setFill(); rect.fill()
		let nsPath = NSBezierPath(); for p in paths { nsPath.append(p.nsBezierPath()) }
		nsPath.lineWidth = 2; NSColor.black.setStroke(); nsPath.stroke()
		img.unlockFocus(); return img
	}
}
