import XCTest
@testable import DevReader

/// Tests for NotesExportService and CodeFileService.
@MainActor
final class ServiceTests: XCTestCase {

	// MARK: - NotesExportService: Preset Management

	func testLoadPresetsEmpty() {
		let presets = NotesExportService.loadPresets(from: "[]")
		XCTAssertTrue(presets.isEmpty)
	}

	func testLoadPresetsInvalidJSON() {
		let presets = NotesExportService.loadPresets(from: "not json")
		XCTAssertTrue(presets.isEmpty, "Invalid JSON should return empty array")
	}

	func testSaveAndLoadPreset() {
		let filter = ExportFilter(
			selectedTag: "swift",
			filterBookmarks: true,
			useDateFilter: false,
			dateFrom: Date(),
			dateTo: Date()
		)
		let raw = NotesExportService.savePreset(name: "My Preset", filter: filter, existing: "[]")
		let presets = NotesExportService.loadPresets(from: raw)

		XCTAssertEqual(presets.count, 1)
		XCTAssertEqual(presets.first?.name, "My Preset")
		XCTAssertEqual(presets.first?.tag, "swift")
		XCTAssertTrue(presets.first?.bookmarks ?? false)
	}

	func testSavePresetOverwritesSameName() {
		let filter1 = ExportFilter(selectedTag: "a", filterBookmarks: false, useDateFilter: false, dateFrom: Date(), dateTo: Date())
		let filter2 = ExportFilter(selectedTag: "b", filterBookmarks: true, useDateFilter: false, dateFrom: Date(), dateTo: Date())

		var raw = NotesExportService.savePreset(name: "Test", filter: filter1, existing: "[]")
		raw = NotesExportService.savePreset(name: "Test", filter: filter2, existing: raw)

		let presets = NotesExportService.loadPresets(from: raw)
		XCTAssertEqual(presets.count, 1, "Same-name preset should be replaced, not duplicated")
		XCTAssertEqual(presets.first?.tag, "b")
	}

	func testDeletePreset() {
		let filter = ExportFilter(selectedTag: nil, filterBookmarks: false, useDateFilter: false, dateFrom: Date(), dateTo: Date())
		let raw = NotesExportService.savePreset(name: "ToDelete", filter: filter, existing: "[]")
		let afterDelete = NotesExportService.deletePreset(named: "ToDelete", existing: raw)

		let presets = NotesExportService.loadPresets(from: afterDelete)
		XCTAssertTrue(presets.isEmpty)
	}

	func testSavePresetRejectsEmptyName() {
		let filter = ExportFilter(selectedTag: nil, filterBookmarks: false, useDateFilter: false, dateFrom: Date(), dateTo: Date())
		let raw = NotesExportService.savePreset(name: "  ", filter: filter, existing: "[]")
		let presets = NotesExportService.loadPresets(from: raw)
		XCTAssertTrue(presets.isEmpty, "Whitespace-only name should be rejected")
	}

	// MARK: - NotesExportService: Export

	func testExportMarkdownCreatesFile() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID().uuidString).md")
		defer { try? FileManager.default.removeItem(at: url) }

		let notes = [
			NoteItem(text: "Hello world", pageIndex: 0, chapter: "Chapter 1"),
			NoteItem(text: "Second note", pageIndex: 1, chapter: "Chapter 2")
		]
		let filter = ExportFilter(selectedTag: nil, filterBookmarks: false, useDateFilter: false, dateFrom: Date(), dateTo: Date())

		let success = await NotesExportService.exportMarkdown(
			to: url,
			pageNotes: [0: "Page note for page 1"],
			items: notes,
			bookmarks: [],
			filter: filter
		)

		XCTAssertTrue(success)
		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

		let content = try? String(contentsOf: url, encoding: .utf8)
		XCTAssertNotNil(content)
		XCTAssertTrue(content?.contains("# Notes Export") ?? false)
		XCTAssertTrue(content?.contains("Hello world") ?? false)
		XCTAssertTrue(content?.contains("Chapter 1") ?? false)
		XCTAssertTrue(content?.contains("Page note for page 1") ?? false)
	}

	func testExportMarkdownFiltersTag() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_tag_\(UUID().uuidString).md")
		defer { try? FileManager.default.removeItem(at: url) }

		let notes = [
			NoteItem(text: "Tagged note", pageIndex: 0, chapter: "Ch1", tags: ["swift"]),
			NoteItem(text: "Untagged note", pageIndex: 1, chapter: "Ch2")
		]
		let filter = ExportFilter(selectedTag: "swift", filterBookmarks: false, useDateFilter: false, dateFrom: Date(), dateTo: Date())

		let success = await NotesExportService.exportMarkdown(to: url, pageNotes: [:], items: notes, bookmarks: [], filter: filter)

		XCTAssertTrue(success)
		let content = try? String(contentsOf: url, encoding: .utf8)
		XCTAssertTrue(content?.contains("Tagged note") ?? false)
		XCTAssertFalse(content?.contains("Untagged note") ?? false, "Notes without matching tag should be excluded")
	}

	func testExportMarkdownFiltersBookmarks() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_bm_\(UUID().uuidString).md")
		defer { try? FileManager.default.removeItem(at: url) }

		let notes = [
			NoteItem(text: "Bookmarked page note", pageIndex: 0, chapter: "Ch1"),
			NoteItem(text: "Non-bookmarked note", pageIndex: 5, chapter: "Ch2")
		]
		let filter = ExportFilter(selectedTag: nil, filterBookmarks: true, useDateFilter: false, dateFrom: Date(), dateTo: Date())

		let success = await NotesExportService.exportMarkdown(
			to: url, pageNotes: [:], items: notes, bookmarks: [0, 2], filter: filter
		)

		XCTAssertTrue(success)
		let content = try? String(contentsOf: url, encoding: .utf8)
		XCTAssertTrue(content?.contains("Bookmarked page note") ?? false)
		XCTAssertFalse(content?.contains("Non-bookmarked note") ?? false, "Notes on non-bookmarked pages should be excluded")
	}

	func testExportMarkdownProgressCallback() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_prog_\(UUID().uuidString).md")
		defer { try? FileManager.default.removeItem(at: url) }

		var progressValues: [Double] = []
		let filter = ExportFilter(selectedTag: nil, filterBookmarks: false, useDateFilter: false, dateFrom: Date(), dateTo: Date())

		_ = await NotesExportService.exportMarkdown(
			to: url,
			pageNotes: [0: "Note"],
			items: [NoteItem(text: "Test", pageIndex: 0, chapter: "Ch")],
			bookmarks: [],
			filter: filter,
			onProgress: { progress, _ in
				progressValues.append(progress)
			}
		)

		XCTAssertFalse(progressValues.isEmpty, "Progress callback should be called")
		// Progress should end at 0.9 (the service reports up to 0.9, caller sets 1.0)
		XCTAssertTrue(progressValues.last ?? 0 >= 0.5, "Progress should reach at least 50%")
	}

	// MARK: - CodeFileService: Path Traversal (covered in SecurityTests too, but exercising API)

	func testCodeFileServiceDetectsLanguage() {
		let swiftURL = URL(fileURLWithPath: "/tmp/test.swift")
		XCTAssertEqual(CodeFileService.detectLanguage(for: swiftURL), .swift)

		let pyURL = URL(fileURLWithPath: "/tmp/test.py")
		XCTAssertEqual(CodeFileService.detectLanguage(for: pyURL), .python)

		let unknownURL = URL(fileURLWithPath: "/tmp/test.xyz")
		XCTAssertNil(CodeFileService.detectLanguage(for: unknownURL))
	}

	func testCodeFileServiceRecentFiles() {
		// Clear any existing recent files first
		UserDefaults.standard.removeObject(forKey: "DevReader.Code.RecentFiles.v1")

		let files = CodeFileService.loadRecentFiles()
		XCTAssertTrue(files.isEmpty, "Should start empty after clearing")

		let url = FileManager.default.temporaryDirectory.appendingPathComponent("recent_test.py")
		try? "print('hi')".write(to: url, atomically: true, encoding: .utf8)
		defer {
			try? FileManager.default.removeItem(at: url)
			UserDefaults.standard.removeObject(forKey: "DevReader.Code.RecentFiles.v1")
		}

		CodeFileService.addToRecentFiles(url)
		let loaded = CodeFileService.loadRecentFiles()
		XCTAssertEqual(loaded.count, 1)
		XCTAssertEqual(loaded.first?.lastPathComponent, "recent_test.py")
	}
}
