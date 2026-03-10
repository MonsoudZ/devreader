import XCTest
import PDFKit
@testable import DevReader

@MainActor
final class NewFeaturesTests: XCTestCase {

	// MARK: - Page Rotation

	func testRotateCurrentPageRight() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 3)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rotate_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		let originalRotation = doc.page(at: 0)?.rotation ?? 0
		ctrl.rotateCurrentPageRight()
		XCTAssertEqual(doc.page(at: 0)?.rotation, (originalRotation + 90) % 360)
	}

	func testRotateCurrentPageLeft() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 3)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rotate_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		let originalRotation = doc.page(at: 0)?.rotation ?? 0
		ctrl.rotateCurrentPageLeft()
		XCTAssertEqual(doc.page(at: 0)?.rotation, (originalRotation + 270) % 360)
	}

	// MARK: - Shortcut Conflict Detection

	func testShortcutConflictDetection() {
		let store = KeyboardShortcutStore()
		addTeardownBlock { [store] in _ = store }
		// Set two actions to the same binding
		let binding = ShortcutBinding(key: "z", command: true, shift: true, option: false, control: false)
		store.update(.highlightSelection, to: binding)
		store.update(.underlineSelection, to: binding)

		let conflicts = store.conflictingActions(for: binding, excluding: .highlightSelection)
		XCTAssertTrue(conflicts.contains(.underlineSelection))
	}

	func testShortcutNoConflictWhenUnique() {
		let store = KeyboardShortcutStore()
		addTeardownBlock { [store] in _ = store }
		let binding = ShortcutBinding(key: "q", command: true, shift: false, option: false, control: false)
		store.update(.highlightSelection, to: binding)

		let conflicts = store.conflictingActions(for: binding, excluding: .highlightSelection)
		XCTAssertTrue(conflicts.isEmpty)
	}

	func testShortcutResetToDefaults() {
		let store = KeyboardShortcutStore()
		addTeardownBlock { [store] in _ = store }
		let custom = ShortcutBinding(key: "z", command: true, shift: true, option: true, control: false)
		store.update(.openPDF, to: custom)
		XCTAssertEqual(store.binding(for: .openPDF), custom)

		store.resetToDefaults()
		XCTAssertEqual(store.binding(for: .openPDF), KeyboardShortcutStore.defaults[.openPDF])
	}

	// MARK: - Note Templates

	func testNoteFromTemplate() {
		let template = NoteItem.templates.first!
		let note = NoteItem.fromTemplate(template, pageIndex: 5, chapter: "Chapter 3")

		XCTAssertEqual(note.title, template.titleTemplate)
		XCTAssertEqual(note.text, template.textTemplate)
		XCTAssertEqual(note.pageIndex, 5)
		XCTAssertEqual(note.chapter, "Chapter 3")
		XCTAssertEqual(note.tags, template.tags)
	}

	func testAllTemplatesHaveRequiredFields() {
		for template in NoteItem.templates {
			XCTAssertFalse(template.name.isEmpty, "Template name should not be empty")
			XCTAssertFalse(template.icon.isEmpty, "Template icon should not be empty")
			XCTAssertFalse(template.titleTemplate.isEmpty, "Template title should not be empty")
			XCTAssertFalse(template.textTemplate.isEmpty, "Template text should not be empty")
		}
	}

	// MARK: - Document Properties

	func testDocumentPropertiesWithNoDocument() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let props = ctrl.documentProperties()
		XCTAssertTrue(props.isEmpty)
	}

	func testDocumentPropertiesWithDocument() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 5)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("props_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		let props = ctrl.documentProperties()
		// Should at least have "Pages" entry
		let pagesEntry = props.first { $0.0 == "Pages" }
		XCTAssertNotNil(pagesEntry)
		XCTAssertEqual(pagesEntry?.1, "5")
	}

	// MARK: - Text-to-Speech

	func testTTSServiceInitialState() {
		let tts = TextToSpeechService()
		addTeardownBlock { [tts] in _ = tts }
		XCTAssertFalse(tts.isSpeaking)
		XCTAssertFalse(tts.isPaused)
		XCTAssertEqual(tts.currentPage, 0)
	}

	func testTTSStopResetsState() {
		let tts = TextToSpeechService()
		addTeardownBlock { [tts] in _ = tts }
		tts.stop()
		XCTAssertFalse(tts.isSpeaking)
		XCTAssertFalse(tts.isPaused)
	}

	// MARK: - Annotation Management

	func testAnnotationsOnCurrentPageEmptyByDefault() {
		let ctrl = PDFController()
		addTeardownBlock { [ctrl] in _ = ctrl }
		let doc = makeDoc(pageCount: 3)
		let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ann_\(UUID()).pdf")
		ctrl.loadForTesting(document: doc, url: url)

		let annotations = ctrl.annotationManager.annotationsOnCurrentPage()
		XCTAssertTrue(annotations.isEmpty)
	}

	// MARK: - Sketch Tools

	func testSketchToolEnumCoverage() {
		let allTools = SketchView.SketchTool.allCases
		XCTAssertEqual(allTools.count, 5)
		XCTAssertTrue(allTools.contains(.pen))
		XCTAssertTrue(allTools.contains(.eraser))
		XCTAssertTrue(allTools.contains(.rectangle))
		XCTAssertTrue(allTools.contains(.circle))
		XCTAssertTrue(allTools.contains(.line))
	}

	func testSketchToolIconsNotEmpty() {
		for tool in SketchView.SketchTool.allCases {
			XCTAssertFalse(tool.icon.isEmpty, "\(tool) icon should not be empty")
			XCTAssertFalse(tool.label.isEmpty, "\(tool) label should not be empty")
		}
	}

	// MARK: - Template Codable

	func testTemplateCodable() throws {
		let template = NoteItem.Template(
			name: "Test", icon: "star", titleTemplate: "My Title",
			textTemplate: "My Body Text", tags: ["test", "review"]
		)
		let data = try JSONEncoder().encode(template)
		let decoded = try JSONDecoder().decode(NoteItem.Template.self, from: data)
		XCTAssertEqual(decoded.name, template.name)
		XCTAssertEqual(decoded.icon, template.icon)
		XCTAssertEqual(decoded.titleTemplate, template.titleTemplate, "titleTemplate should round-trip")
		XCTAssertEqual(decoded.textTemplate, template.textTemplate, "textTemplate should round-trip")
		XCTAssertEqual(decoded.tags, template.tags)
	}
}
