import XCTest
@testable import DevReader

final class BackupRestoreTests: XCTestCase {

	override func setUp() {
		super.setUp()
		// Clean slate: remove old data/backups and recreate directories
		try? FileManager.default.removeItem(at: JSONStorageService.dataDirectory)
		try? FileManager.default.removeItem(at: JSONStorageService.backupDirectory)
		JSONStorageService.ensureDirectories()
	}

	override func tearDown() {
		// Clean up data and backup directories, then recreate for other test suites
		try? FileManager.default.removeItem(at: JSONStorageService.dataDirectory)
		try? FileManager.default.removeItem(at: JSONStorageService.backupDirectory)
		JSONStorageService.ensureDirectories()
		super.tearDown()
	}

	// MARK: - Helpers

	private func sampleLibrary() -> [DevReader.LibraryItem] {
		[
			DevReader.LibraryItem(
				url: URL(fileURLWithPath: "/tmp/test1.pdf"),
				title: "Test Book 1",
				author: "Author A",
				pageCount: 100,
				fileSize: 50000,
				tags: ["swift", "ios"]
			),
			DevReader.LibraryItem(
				url: URL(fileURLWithPath: "/tmp/test2.pdf"),
				title: "Test Book 2",
				author: "Author B",
				pageCount: 200,
				fileSize: 120000,
				tags: ["rust"]
			),
		]
	}

	private func sampleNotes() -> [NoteItem] {
		[
			NoteItem(title: "Chapter Summary", text: "Key points about chapter 1", pageIndex: 5, chapter: "Chapter 1", tags: ["summary"]),
			NoteItem(title: "Question", text: "What does X mean?", pageIndex: 12, chapter: "Chapter 3", tags: ["question"]),
		]
	}

	private func sampleAnnotations() -> [PDFAnnotationData] {
		[
			PDFAnnotationData(
				pageIndex: 0,
				bounds: CodableRect(from: CGRect(x: 10, y: 20, width: 200, height: 14)),
				type: .highlight,
				colorName: "yellow",
				text: "highlighted text"
			),
			PDFAnnotationData(
				pageIndex: 1,
				bounds: CodableRect(from: CGRect(x: 50, y: 100, width: 150, height: 12)),
				type: .underline,
				colorName: "blue",
				text: "underlined text"
			),
		]
	}

	private func sampleSketches() -> [SketchItem] {
		[
			SketchItem(
				pdfURL: URL(fileURLWithPath: "/tmp/test1.pdf"),
				pageIndex: 3,
				title: "Diagram sketch",
				createdDate: Date(),
				lastModified: Date(),
				canvasData: Data("canvas-data".utf8),
				strokesData: Data("strokes-data".utf8)
			),
		]
	}

	private func seedFullData() throws -> DevReaderData {
		let library = sampleLibrary()
		let notes = sampleNotes()
		let annotations = sampleAnnotations()
		let sketches = sampleSketches()
		let hash = "testhash123"

		let data = DevReaderData(
			library: library,
			recentDocuments: ["file:///tmp/test1.pdf", "file:///tmp/test2.pdf"],
			pinnedDocuments: ["file:///tmp/test1.pdf"],
			webBookmarks: ["https://example.com", "https://docs.swift.org"],
			annotationBundles: [AnnotationBundle(hash: hash, annotations: annotations)],
			notesBundles: [NotesBundle(hash: hash, notes: notes, pageNotes: [0: "Page note on cover", 5: "Page note on ch1"], tags: ["swift", "notes"])],
			bookmarksBundles: [BookmarksBundle(hash: hash, bookmarks: [0, 5, 12, 50])],
			sessionBundles: [SessionBundle(hash: hash, data: Data("{\"page\":5}".utf8))],
			sketches: sketches,
			exportDate: Date(),
			version: "3.0"
		)
		return data
	}

	// MARK: - Round-Trip: Export → Import → Re-Export

	func testFullRoundTrip() throws {
		let original = try seedFullData()

		// Import the data
		try JSONStorageService.importAllData(original)

		// Re-export
		let exported = try JSONStorageService.exportAllData()

		// Verify library
		XCTAssertEqual(exported.library.count, original.library.count)
		for (exp, orig) in zip(exported.library.sorted(by: { $0.title < $1.title }), original.library.sorted(by: { $0.title < $1.title })) {
			XCTAssertEqual(exp.title, orig.title)
			XCTAssertEqual(exp.author, orig.author)
			XCTAssertEqual(exp.pageCount, orig.pageCount)
			XCTAssertEqual(exp.fileSize, orig.fileSize)
			XCTAssertEqual(exp.tags, orig.tags)
		}

		// Verify recent documents
		XCTAssertEqual(exported.recentDocuments.sorted(), original.recentDocuments.sorted())

		// Verify pinned documents
		XCTAssertEqual(exported.pinnedDocuments.sorted(), original.pinnedDocuments.sorted())

		// Verify web bookmarks
		XCTAssertEqual(exported.webBookmarks?.sorted(), original.webBookmarks?.sorted())

		// Verify annotations
		XCTAssertEqual(exported.annotationBundles?.count, original.annotationBundles?.count)
		if let expBundle = exported.annotationBundles?.first, let origBundle = original.annotationBundles?.first {
			XCTAssertEqual(expBundle.hash, origBundle.hash)
			XCTAssertEqual(expBundle.annotations.count, origBundle.annotations.count)
			for (ea, oa) in zip(expBundle.annotations, origBundle.annotations) {
				XCTAssertEqual(ea.pageIndex, oa.pageIndex)
				XCTAssertEqual(ea.type, oa.type)
				XCTAssertEqual(ea.colorName, oa.colorName)
				XCTAssertEqual(ea.text, oa.text)
			}
		}

		// Verify notes bundles
		XCTAssertEqual(exported.notesBundles?.count, original.notesBundles?.count)
		if let expBundle = exported.notesBundles?.first, let origBundle = original.notesBundles?.first {
			XCTAssertEqual(expBundle.hash, origBundle.hash)
			XCTAssertEqual(expBundle.notes.count, origBundle.notes.count)
			XCTAssertEqual(expBundle.pageNotes, origBundle.pageNotes)
			XCTAssertEqual(expBundle.tags, origBundle.tags)
			for (en, on) in zip(expBundle.notes.sorted(by: { $0.title < $1.title }), origBundle.notes.sorted(by: { $0.title < $1.title })) {
				XCTAssertEqual(en.title, on.title)
				XCTAssertEqual(en.text, on.text)
				XCTAssertEqual(en.pageIndex, on.pageIndex)
				XCTAssertEqual(en.chapter, on.chapter)
				XCTAssertEqual(en.tags, on.tags)
			}
		}

		// Verify bookmarks bundles
		XCTAssertEqual(exported.bookmarksBundles?.count, original.bookmarksBundles?.count)
		if let expBundle = exported.bookmarksBundles?.first, let origBundle = original.bookmarksBundles?.first {
			XCTAssertEqual(expBundle.hash, origBundle.hash)
			XCTAssertEqual(expBundle.bookmarks.sorted(), origBundle.bookmarks.sorted())
		}

		// Verify session bundles
		XCTAssertEqual(exported.sessionBundles?.count, original.sessionBundles?.count)
		if let expBundle = exported.sessionBundles?.first, let origBundle = original.sessionBundles?.first {
			XCTAssertEqual(expBundle.hash, origBundle.hash)
			XCTAssertEqual(expBundle.data, origBundle.data)
		}

		// Verify sketches
		XCTAssertEqual(exported.sketches?.count, original.sketches?.count)
		if let expSketch = exported.sketches?.first, let origSketch = original.sketches?.first {
			XCTAssertEqual(expSketch.title, origSketch.title)
			XCTAssertEqual(expSketch.pageIndex, origSketch.pageIndex)
			XCTAssertEqual(expSketch.canvasData, origSketch.canvasData)
			XCTAssertEqual(expSketch.strokesData, origSketch.strokesData)
		}
	}

	// MARK: - Backup → Corrupt → Restore

	func testBackupCorruptRestore() throws {
		let original = try seedFullData()
		try JSONStorageService.importAllData(original)

		// Create backup
		let backupURL = try JSONStorageService.createBackup()
		// Copy to a safe location so restoreFromBackup's internal pre-restore backup doesn't interfere
		let safeCopy = FileManager.default.temporaryDirectory.appendingPathComponent("safe_backup_\(UUID()).json")
		try FileManager.default.copyItem(at: backupURL, to: safeCopy)

		// Corrupt the data: wipe the data directory
		let dataDir = JSONStorageService.dataDirectory
		try FileManager.default.removeItem(at: dataDir)
		JSONStorageService.ensureDirectories()

		// Verify data is gone
		let corruptedExport = try JSONStorageService.exportAllData()
		XCTAssertTrue(corruptedExport.library.isEmpty, "Library should be empty after corruption")

		// Restore from the safe copy (avoids restoreFromBackup touching the same backup dir)
		let backupData = try JSONDecoder().decode(DevReaderData.self, from: Data(contentsOf: safeCopy))
		try JSONStorageService.importAllData(backupData)

		// Verify data is back
		let restored = try JSONStorageService.exportAllData()
		XCTAssertEqual(restored.library.count, original.library.count)
		XCTAssertEqual(restored.annotationBundles?.count ?? 0, original.annotationBundles?.count ?? 0)
		if let restoredAnns = restored.annotationBundles?.first, let origAnns = original.annotationBundles?.first {
			XCTAssertEqual(restoredAnns.annotations.count, origAnns.annotations.count)
		}
		XCTAssertEqual(restored.notesBundles?.first?.notes.count, original.notesBundles?.first?.notes.count)
		XCTAssertEqual(restored.bookmarksBundles?.first?.bookmarks.sorted(), original.bookmarksBundles?.first?.bookmarks.sorted())
		XCTAssertEqual(restored.sketches?.count, original.sketches?.count)
		XCTAssertEqual(restored.webBookmarks?.sorted(), original.webBookmarks?.sorted())

		// Clean up safe copy
		try? FileManager.default.removeItem(at: safeCopy)
	}

	// MARK: - Empty Data Round-Trip

	func testEmptyDataRoundTrip() throws {
		let empty = DevReaderData(
			library: [],
			recentDocuments: [],
			pinnedDocuments: [],
			exportDate: Date(),
			version: "3.0"
		)

		try JSONStorageService.importAllData(empty)
		let exported = try JSONStorageService.exportAllData()

		XCTAssertTrue(exported.library.isEmpty)
		XCTAssertTrue(exported.recentDocuments.isEmpty)
		XCTAssertTrue(exported.pinnedDocuments.isEmpty)
	}

	// MARK: - Partial Data (Optional Bundles)

	func testPartialDataRoundTrip() throws {
		// Data with library + notes but no annotations, bookmarks, sessions, or sketches
		let data = DevReaderData(
			library: sampleLibrary(),
			recentDocuments: ["file:///tmp/test1.pdf"],
			pinnedDocuments: [],
			webBookmarks: nil,
			annotationBundles: nil,
			notesBundles: [NotesBundle(hash: "abc123", notes: sampleNotes(), pageNotes: nil, tags: nil)],
			bookmarksBundles: nil,
			sessionBundles: nil,
			sketches: nil,
			exportDate: Date(),
			version: "3.0"
		)

		try JSONStorageService.importAllData(data)
		let exported = try JSONStorageService.exportAllData()

		XCTAssertEqual(exported.library.count, 2)
		XCTAssertEqual(exported.notesBundles?.first?.notes.count, 2)
		// Optional bundles that weren't set should remain nil or empty
		XCTAssertNil(exported.sketches)
	}

	// MARK: - Multiple Backups + Cleanup

	func testCleanupOldBackups() throws {
		// Create backup files manually to avoid timestamp collisions
		let backupDir = JSONStorageService.backupDirectory
		for i in 0..<12 {
			let name = "backup_2026-01-01_00-00-\(String(format: "%02d", i)).json"
			let url = backupDir.appendingPathComponent(name)
			let dummy = DevReaderData(library: [], recentDocuments: [], pinnedDocuments: [], exportDate: Date(), version: "3.0")
			let data = try JSONEncoder().encode(dummy)
			try data.write(to: url)
		}

		let beforeCleanup = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
			.filter { $0.lastPathComponent.hasPrefix("backup_") }
		XCTAssertEqual(beforeCleanup.count, 12)

		// Cleanup keeping 5
		JSONStorageService.cleanupOldBackups(keepCount: 5)

		let afterCleanup = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
			.filter { $0.lastPathComponent.hasPrefix("backup_") }
		XCTAssertLessThanOrEqual(afterCleanup.count, 5)
	}

	// MARK: - Import Atomicity

	func testImportDoesNotLeaveStagingDirectory() throws {
		let data = try seedFullData()
		try JSONStorageService.importAllData(data)

		// Check no staging directories remain
		let appSupport = JSONStorageService.appSupportURL
		let contents = try FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
		let stagingDirs = contents.filter { $0.lastPathComponent.hasPrefix("ImportStaging-") }
		XCTAssertTrue(stagingDirs.isEmpty, "Staging directory should be cleaned up after import")
	}

	// MARK: - Backup File Format

	func testBackupIsValidJSON() throws {
		let data = try seedFullData()
		try JSONStorageService.importAllData(data)

		let backupURL = try JSONStorageService.createBackup()
		let backupData = try Data(contentsOf: backupURL)

		// Should be valid JSON
		let decoded = try JSONDecoder().decode(DevReaderData.self, from: backupData)
		XCTAssertEqual(decoded.version, "3.0")
		XCTAssertEqual(decoded.library.count, 2)
	}

	// MARK: - Overwrite Import

	func testImportOverwritesExistingData() throws {
		// First import
		let firstData = DevReaderData(
			library: [LibraryItem(url: URL(fileURLWithPath: "/tmp/old.pdf"), title: "Old Book", pageCount: 10, fileSize: 1000)],
			recentDocuments: [],
			pinnedDocuments: [],
			exportDate: Date(),
			version: "3.0"
		)
		try JSONStorageService.importAllData(firstData)

		// Second import with different data
		let secondData = DevReader.DevReaderData(
			library: sampleLibrary(),
			recentDocuments: ["file:///tmp/test1.pdf"],
			pinnedDocuments: [],
			exportDate: Date(),
			version: "3.0"
		)
		try JSONStorageService.importAllData(secondData)

		let exported = try JSONStorageService.exportAllData()
		// Should have the second import's data, not the first
		XCTAssertEqual(exported.library.count, 2)
		XCTAssertTrue(exported.library.contains(where: { $0.title == "Test Book 1" }))
		XCTAssertFalse(exported.library.contains(where: { $0.title == "Old Book" }))
	}

	// MARK: - Data Integrity Validation

	func testDataIntegrityAfterRoundTrip() throws {
		let data = try seedFullData()
		try JSONStorageService.importAllData(data)

		let issues = JSONStorageService.validateDataIntegrity()
		// Filter to only issues about our test data files
		let dataIssues = issues.filter { !$0.contains("Could not read") }
		XCTAssertTrue(dataIssues.isEmpty, "No data integrity issues expected, got: \(dataIssues)")
	}
}
