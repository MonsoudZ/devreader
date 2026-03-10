import SwiftUI
import PDFKit
import Combine

@MainActor
final class PDFSelectionBridge {
	weak var pdfView: PDFView?
	var cancellables = Set<AnyCancellable>()
	var currentSelection: PDFSelection? { pdfView?.currentSelection }
	/// Caches the last non-empty selection text so menu commands can access it
	/// even after the menu activation clears the PDFView selection.
	private(set) var cachedSelectionText: String?
	private var selectionTask: Task<Void, Never>?

	deinit {
		selectionTask?.cancel()
	}

    func setHighlightedSelections(_ selections: [PDFSelection]) { pdfView?.highlightedSelections = selections }

	func observeSelectionChanges(from pdfView: PDFView) {
		selectionTask?.cancel()
		selectionTask = Task { [weak self] in
			for await _ in NotificationCenter.default.notifications(named: .PDFViewSelectionChanged, object: pdfView) {
				guard let self else { break }
				if let text = self.pdfView?.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
				   !text.isEmpty {
					self.cachedSelectionText = text
				}
			}
		}
	}
}

/// PDFView subclass that posts a notification after the standard copy action.
final class CopyAwarePDFView: PDFView {
	static let didCopyNotification = Notification.Name("DevReader.PDFView.didCopy")

	override func copy(_ sender: Any?) {
		super.copy(sender)
		NotificationCenter.default.post(name: Self.didCopyNotification, object: self)
	}
}

/// PDF dark mode rendering options.
/// "auto" follows system appearance, "off" always renders normally, "sepia" applies a warm tint.
nonisolated enum PDFDarkModeStyle: String, CaseIterable, Sendable {
	case off = "off"
	case auto = "auto"
	case sepia = "sepia"

	var displayName: String {
		switch self {
		case .off: "Normal"
		case .auto: "Dark (invert)"
		case .sepia: "Sepia"
		}
	}
}

struct PDFViewRepresentable: NSViewRepresentable {
    @ObservedObject var pdf: PDFController
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.0
    @AppStorage("pdfDarkMode") private var pdfDarkMode: String = "off"
    @Environment(\.colorScheme) private var colorScheme

	func makeNSView(context: Context) -> PDFView {
		let v = CopyAwarePDFView()

		// Basic configuration
		v.autoScales = false
		v.displayMode = .singlePageContinuous
		v.backgroundColor = .windowBackgroundColor
		v.delegate = context.coordinator
		pdf.selectionBridge.pdfView = v
		pdf.selectionBridge.observeSelectionChanges(from: v)
		context.coordinator.observeScaleChanges(from: v)

		// Aggressive memory optimization
		v.interpolationQuality = .low
		v.pageShadowsEnabled = false
		v.displayBox = .mediaBox
		v.pageBreakMargins = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

		// Conservative scaling limits
		v.maxScaleFactor = 2.0
		v.minScaleFactor = 0.3

		// Set initial zoom
		if defaultZoom > 0 {
			v.scaleFactor = min(defaultZoom, 1.5)
		}

		// Enable layer-backing for Core Image filters
		v.wantsLayer = true

		// Accessibility support
		v.setAccessibilityLabel("PDF Document")
		v.setAccessibilityRole(.group)
		v.setAccessibilityHelp("PDF document viewer. Use arrow keys to navigate pages, Command+F to search, and Command+Plus/Minus to zoom.")

		return v
	}

	func updateNSView(_ nsView: PDFView, context: Context) {
		// Only update document if it actually changed
		let documentChanged = nsView.document !== pdf.document
		if documentChanged {
			nsView.document = pdf.document
			context.coordinator.hasSetInitialZoom = false
		}

		// Only navigate to page if it's different and valid (with safety checks)
		if let doc = pdf.document,
		   pdf.currentPageIndex >= 0,
		   pdf.currentPageIndex < doc.pageCount,
		   let targetPage = doc.page(at: pdf.currentPageIndex),
		   nsView.currentPage !== targetPage {
			nsView.go(to: targetPage)
		}

		// Only set zoom when the document changes, not on every update
		// This prevents overriding the user's manual pinch-zoom
		if !context.coordinator.hasSetInitialZoom, pdf.document != nil {
			let safeZoom = max(0.3, min(defaultZoom, 2.0))
			if safeZoom > 0 {
				nsView.scaleFactor = safeZoom
			}
			context.coordinator.hasSetInitialZoom = true
		}

		// Only re-apply filter when style or color scheme changes
		let style = PDFDarkModeStyle(rawValue: pdfDarkMode) ?? .off
		let isDark = colorScheme == .dark
		let key = AppearanceKey(style: style, isDark: isDark)
		if context.coordinator.lastAppearance != key {
			context.coordinator.lastAppearance = key
			applyAppearanceFilter(to: nsView, style: style, isDark: isDark)
		}
	}

	struct AppearanceKey: Equatable {
		let style: PDFDarkModeStyle
		let isDark: Bool
	}

	private func applyAppearanceFilter(to view: PDFView, style: PDFDarkModeStyle, isDark: Bool) {
		switch style {
		case .off:
			view.layer?.compositingFilter = nil
			view.backgroundColor = .windowBackgroundColor
		case .auto where isDark:
			if let filter = CIFilter(name: "CIColorInvert") {
				view.layer?.compositingFilter = filter
			}
			view.backgroundColor = .windowBackgroundColor
		case .auto:
			view.layer?.compositingFilter = nil
			view.backgroundColor = .windowBackgroundColor
		case .sepia:
			if let filter = CIFilter(name: "CISepiaTone") {
				filter.setValue(0.4, forKey: kCIInputIntensityKey)
				view.layer?.compositingFilter = filter
			}
			view.backgroundColor = NSColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1.0)
		}
	}

	func makeCoordinator() -> Coord { Coord(parent: self) }

	final class Coord: NSObject, PDFViewDelegate {
		let parent: PDFViewRepresentable
		var hasSetInitialZoom = false
		var lastAppearance: AppearanceKey?
		nonisolated(unsafe) private var scaleObserver: Any?
		private var scaleDebounceTask: Task<Void, Never>?

		init(parent: PDFViewRepresentable) {
			self.parent = parent
			super.init()
		}

		func observeScaleChanges(from pdfView: PDFView) {
			scaleObserver.map { NotificationCenter.default.removeObserver($0) }
			scaleObserver = NotificationCenter.default.addObserver(
				forName: .PDFViewScaleChanged, object: pdfView, queue: .main
			) { [weak self] notification in
				guard let pdfView = notification.object as? PDFView else { return }
				Task { @MainActor in
					// Cancel previous debounce to coalesce rapid pinch-zoom events
					self?.scaleDebounceTask?.cancel()
					self?.scaleDebounceTask = Task { @MainActor in
						try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
						guard !Task.isCancelled else { return }
						self?.parent.pdf.scaleFactor = pdfView.scaleFactor
					}
				}
			}
		}

		func pdfViewPageChanged(_ sender: PDFView) {
			guard let doc = sender.document, let page = sender.currentPage else { return }
			let idx = doc.index(for: page)
			if idx != parent.pdf.currentPageIndex && idx >= 0 && idx < doc.pageCount {
				parent.pdf.didScrollToPage(idx)
			}
		}

		deinit {
			if let observer = scaleObserver {
				NotificationCenter.default.removeObserver(observer)
			}
		}
	}
}
