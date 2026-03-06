import Foundation
@preconcurrency import PDFKit
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
final class PDFAnnotationManager: ObservableObject {
	private weak var pdfController: PDFController?
	private let persistenceService: AnnotationPersistenceProtocol
	private var annotations: [PDFAnnotationData] = []
	private var persister: DebouncedPersister?
	private var isRestoring = false

	init(pdfController: PDFController, persistenceService: AnnotationPersistenceProtocol? = nil) {
		self.pdfController = pdfController
		self.persistenceService = persistenceService ?? AnnotationPersistenceService()
	}

	// MARK: - Annotation Application

	/// Adds a visual highlight annotation on the PDF page for the current selection.
	func highlightSelection() {
		applyAnnotation(type: .highlight, toastMessage: "Text highlighted on PDF")
	}

	/// Adds an underline annotation on the current selection.
	func underlineSelection() {
		applyAnnotation(type: .underline, toastMessage: "Text underlined on PDF")
	}

	/// Adds a strikethrough annotation on the current selection.
	func strikethroughSelection() {
		applyAnnotation(type: .strikethrough, toastMessage: "Text strikethrough on PDF")
	}

	private func applyAnnotation(type: PDFAnnotationData.AnnotationType, toastMessage: String) {
		guard let ctrl = pdfController else { return }
		guard applyAnnotationOnSelection(type: type) else {
			ctrl.toastRequestPublisher.send(
				ToastMessage(message: "Select text in the PDF first", type: .warning)
			)
			return
		}
		ctrl.toastRequestPublisher.send(
			ToastMessage(message: toastMessage, type: .success)
		)
	}

	/// Core annotation logic shared by all annotation types and captureHighlightToNotes().
	/// Returns true if an annotation was applied, false if no valid selection.
	@discardableResult
	private func applyAnnotationOnSelection(type: PDFAnnotationData.AnnotationType = .highlight) -> Bool {
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
		let color = Self.annotationColor(for: colorName)
		let pdfAnnotationType = Self.pdfSubtype(for: type)

		var didApply = false
		for page in selection.pages {
			let pageIndex = doc.index(for: page)
			guard pageIndex >= 0, pageIndex < doc.pageCount else { continue }
			let selectionBounds = selection.bounds(for: page)
			guard selectionBounds.width > 0 && selectionBounds.height > 0 else { continue }
			let annotation = PDFAnnotation(bounds: selectionBounds, forType: pdfAnnotationType, withProperties: nil)
			annotation.color = color
			page.addAnnotation(annotation)

			let selectedText = selection.string

			let record = PDFAnnotationData(
				pageIndex: pageIndex,
				bounds: CodableRect(from: selectionBounds),
				type: type,
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

			let pdfAnnotation = PDFAnnotation(bounds: record.bounds.cgRect, forType: Self.pdfSubtype(for: record.type), withProperties: nil)
			pdfAnnotation.color = Self.annotationColor(for: record.colorName)
			page.addAnnotation(pdfAnnotation)
		}
	}

	func clearAnnotations() {
		annotations.removeAll()
		persister = nil
	}

	/// Removes the annotation at the given index and its visual counterpart from the PDF page.
	func removeAnnotation(at index: Int) {
		guard let ctrl = pdfController, let doc = ctrl.document,
			  index >= 0, index < annotations.count else { return }
		let record = annotations[index]

		// Remove visual annotation from PDF page
		if let page = doc.page(at: record.pageIndex) {
			let matchingAnnotations = page.annotations.filter { ann in
				ann.bounds == record.bounds.cgRect &&
				ann.type == Self.pdfSubtype(for: record.type).rawValue
			}
			for ann in matchingAnnotations {
				page.removeAnnotation(ann)
			}
		}

		annotations.remove(at: index)
		if let url = ctrl.currentPDFURL { schedulePersist(for: url) }
		ctrl.toastRequestPublisher.send(
			ToastMessage(message: "Annotation removed", type: .success)
		)
	}

	/// Removes all annotations from the current page.
	func removeAnnotationsOnCurrentPage() {
		guard let ctrl = pdfController, let doc = ctrl.document,
			  let url = ctrl.currentPDFURL else { return }
		let pageIndex = ctrl.currentPageIndex

		// Remove visual annotations
		if let page = doc.page(at: pageIndex) {
			let toRemove = page.annotations.filter { ann in
				[PDFAnnotationSubtype.highlight.rawValue,
				 PDFAnnotationSubtype.underline.rawValue,
				 PDFAnnotationSubtype.strikeOut.rawValue].contains(ann.type)
			}
			for ann in toRemove {
				page.removeAnnotation(ann)
			}
		}

		// Remove from data records
		let before = annotations.count
		annotations.removeAll { $0.pageIndex == pageIndex }
		let removed = before - annotations.count

		if removed > 0 {
			schedulePersist(for: url)
			ctrl.toastRequestPublisher.send(
				ToastMessage(message: "\(removed) annotation(s) removed from page \(pageIndex + 1)", type: .success)
			)
		}
	}

	/// Returns annotation records for the current page (for UI listing).
	func annotationsOnCurrentPage() -> [(index: Int, record: PDFAnnotationData)] {
		guard let ctrl = pdfController else { return [] }
		return annotations.enumerated().compactMap { (i, record) in
			record.pageIndex == ctrl.currentPageIndex ? (i, record) : nil
		}
	}

	// MARK: - Debounced Persistence

	func flushPendingPersistence() {
		persister?.flush()
	}

	private func schedulePersist(for url: URL) {
		guard !isRestoring else { return }
		if persister == nil {
			persister = DebouncedPersister { [weak self] in
				guard let self, let currentURL = self.pdfController?.currentPDFURL else { return }
				self.persistNow(for: currentURL)
			}
		}
		persister?.schedule()
	}

	private func persistNow(for url: URL) {
		do {
			try persistenceService.saveAnnotations(annotations, for: url)
		} catch {
			logError(AppLog.pdf, "Failed to persist annotations: \(error)")
		}
	}

	// MARK: - Export PDF with Annotations

	/// Exports the current PDF document with all annotations baked in.
	func exportAnnotatedPDF() {
		guard let ctrl = pdfController, let doc = ctrl.document else {
			pdfController?.toastRequestPublisher.send(
				ToastMessage(message: "No PDF open to export", type: .warning)
			)
			return
		}

		let panel = NSSavePanel()
		panel.allowedContentTypes = [.pdf]
		let baseName = ctrl.currentPDFURL?.deletingPathExtension().lastPathComponent ?? "Annotated"
		panel.nameFieldStringValue = "\(baseName)-annotated.pdf"

		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			if doc.write(to: url) {
				ctrl.toastRequestPublisher.send(
					ToastMessage(message: "Annotated PDF exported", type: .success)
				)
			} else {
				ctrl.toastRequestPublisher.send(
					ToastMessage(message: "Failed to export PDF", type: .error)
				)
			}
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
		applyAnnotationOnSelection(type: .highlight)
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

	// MARK: - Shared Helpers

	private static func annotationColor(for name: String) -> NSColor {
		switch name {
		case "green": .systemGreen.withAlphaComponent(0.3)
		case "blue": .systemBlue.withAlphaComponent(0.3)
		case "pink": .systemPink.withAlphaComponent(0.3)
		default: .systemYellow.withAlphaComponent(0.3)
		}
	}

	private static func pdfSubtype(for type: PDFAnnotationData.AnnotationType) -> PDFAnnotationSubtype {
		switch type {
		case .highlight: .highlight
		case .underline: .underline
		case .strikethrough: .strikeOut
		}
	}
}
