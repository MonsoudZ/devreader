import Foundation
@preconcurrency import PDFKit
import Combine
import AppKit

@MainActor
final class PDFAnnotationManager: ObservableObject {
	private weak var pdfController: PDFController?
	private let persistenceService: AnnotationPersistenceProtocol
	private var annotations: [PDFAnnotationData] = []
	nonisolated(unsafe) private var persistWorkItem: DispatchWorkItem?
	private var isRestoring = false

	init(pdfController: PDFController, persistenceService: AnnotationPersistenceProtocol? = nil) {
		self.pdfController = pdfController
		self.persistenceService = persistenceService ?? AnnotationPersistenceService()
	}

	deinit {
		persistWorkItem?.cancel()
	}

	// MARK: - Highlight Selection

	/// Adds a visual highlight annotation on the PDF page for the current selection.
	func highlightSelection() {
		guard let ctrl = pdfController else { return }
		guard applyHighlightAnnotation() else {
			ctrl.toastRequestPublisher.send(
				ToastMessage(message: "Select text in the PDF first", type: .warning)
			)
			return
		}
		ctrl.toastRequestPublisher.send(
			ToastMessage(message: "Text highlighted on PDF", type: .success)
		)
	}

	/// Core highlight logic shared by highlightSelection() and captureHighlightToNotes().
	/// Returns true if a highlight was applied, false if no valid selection.
	@discardableResult
	private func applyHighlightAnnotation() -> Bool {
		guard let ctrl = pdfController,
			  let doc = ctrl.document, let pdfURL = ctrl.currentPDFURL else { return false }
		let bridge = ctrl.selectionBridge
		guard let selection = bridge.pdfView?.currentSelection ?? {
			guard let cached = bridge.cachedSelectionText else { return nil }
			return doc.findString(cached, withOptions: [.caseInsensitive]).first
		}() else {
			return false
		}

		let colorName = UserDefaults.standard.string(forKey: "highlightColor") ?? "yellow"
		let color: NSColor = switch colorName {
		case "green": .systemGreen.withAlphaComponent(0.3)
		case "blue": .systemBlue.withAlphaComponent(0.3)
		case "pink": .systemPink.withAlphaComponent(0.3)
		default: .systemYellow.withAlphaComponent(0.3)
		}

		var didApply = false
		for page in selection.pages {
			let pageIndex = doc.index(for: page)
			guard pageIndex >= 0, pageIndex < doc.pageCount else { continue }
			let selectionBounds = selection.bounds(for: page)
			guard selectionBounds.width > 0 && selectionBounds.height > 0 else { continue }
			let annotation = PDFAnnotation(bounds: selectionBounds, forType: .highlight, withProperties: nil)
			annotation.color = color
			page.addAnnotation(annotation)

			let selectedText = selection.string

			let record = PDFAnnotationData(
				pageIndex: pageIndex,
				bounds: CodableRect(from: selectionBounds),
				colorName: colorName,
				text: selectedText
			)
			annotations.append(record)
			didApply = true
		}

		if didApply { schedulePersist(for: pdfURL) }
		return didApply
	}

	// MARK: - Restore / Clear

	func restoreAnnotations(for url: URL) {
		isRestoring = true
		defer { isRestoring = false }

		annotations = persistenceService.loadAnnotations(for: url)
		guard let doc = pdfController?.document, !annotations.isEmpty else { return }

		for record in annotations {
			guard record.pageIndex >= 0, record.pageIndex < doc.pageCount,
				  let page = doc.page(at: record.pageIndex) else { continue }

			let color: NSColor = switch record.colorName {
			case "green": .systemGreen.withAlphaComponent(0.3)
			case "blue": .systemBlue.withAlphaComponent(0.3)
			case "pink": .systemPink.withAlphaComponent(0.3)
			default: .systemYellow.withAlphaComponent(0.3)
			}

			let pdfAnnotation: PDFAnnotation
			switch record.type {
			case .highlight:
				pdfAnnotation = PDFAnnotation(bounds: record.bounds.cgRect, forType: .highlight, withProperties: nil)
			case .underline:
				pdfAnnotation = PDFAnnotation(bounds: record.bounds.cgRect, forType: .underline, withProperties: nil)
			}
			pdfAnnotation.color = color
			page.addAnnotation(pdfAnnotation)
		}
	}

	func clearAnnotations() {
		annotations.removeAll()
		persistWorkItem?.cancel()
		persistWorkItem = nil
	}

	// MARK: - Debounced Persistence

	func flushPendingPersistence() {
		if let workItem = persistWorkItem {
			workItem.cancel()
			persistWorkItem = nil
			guard let url = pdfController?.currentPDFURL else { return }
			persistNow(for: url)
		}
	}

	private func schedulePersist(for url: URL) {
		guard !isRestoring else { return }
		persistWorkItem?.cancel()
		let workItem = DispatchWorkItem { @Sendable [weak self] in
			Task { @MainActor in
				guard let self = self, let currentURL = self.pdfController?.currentPDFURL else { return }
				self.persistNow(for: currentURL)
			}
		}
		persistWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
	}

	private func persistNow(for url: URL) {
		do {
			try persistenceService.saveAnnotations(annotations, for: url)
		} catch {
			logError(AppLog.pdf, "Failed to persist annotations: \(error)")
		}
	}

	// MARK: - Highlight and Notes Integration

	func captureHighlightToNotes() {
		guard let ctrl = pdfController, ctrl.currentPDFURL != nil else { return }
		let bridge = ctrl.selectionBridge
		let liveText = bridge.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
		let selectedText = (liveText?.isEmpty == false) ? liveText : bridge.cachedSelectionText
		guard let text = selectedText, !text.isEmpty else {
			ctrl.toastRequestPublisher.send(
				ToastMessage(message: "Select text in the PDF first", type: .warning)
			)
			return
		}
		let note = NoteItem(
			title: "Highlight from page \(ctrl.currentPageIndex + 1)",
			text: text,
			pageIndex: ctrl.currentPageIndex,
			chapter: getCurrentChapter() ?? "Unknown Chapter"
		)
		// Also add a visual highlight annotation on the PDF page (no toast — the note itself is the feedback)
		applyHighlightAnnotation()
		ctrl.noteRequestPublisher.send(note)
	}

	func getCurrentChapter() -> String? {
		guard let ctrl = pdfController else { return nil }
		if let chapter = ctrl.outlineManager.outlineMap[ctrl.currentPageIndex] {
			return chapter
		}
		for i in stride(from: ctrl.currentPageIndex - 1, through: 0, by: -1) {
			if let chapter = ctrl.outlineManager.outlineMap[i] {
				return chapter
			}
		}
		return ctrl.document?.outlineRoot?.label
	}

	func addStickyNote() {
		guard let ctrl = pdfController, ctrl.currentPDFURL != nil else { return }
		let bridge = ctrl.selectionBridge
		let liveText = bridge.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
		let selectedText = (liveText?.isEmpty == false) ? liveText : bridge.cachedSelectionText
		let noteText = selectedText ?? ""
		let stickyNote = NoteItem(
			title: "Sticky note — page \(ctrl.currentPageIndex + 1)",
			text: noteText,
			pageIndex: ctrl.currentPageIndex,
			chapter: getCurrentChapter() ?? "Unknown Chapter",
			tags: ["sticky"]
		)
		ctrl.noteRequestPublisher.send(stickyNote)
		ctrl.toastRequestPublisher.send(
			ToastMessage(message: "Sticky note added", type: .success)
		)
	}
}
