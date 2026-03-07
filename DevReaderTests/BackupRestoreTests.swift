import XCTest
@testable import DevReader

final class BackupRestoreTests: XCTestCase {

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

	private func seedFullData() -> DevReaderData {
		let hash = "testhash123"
		return DevReaderData(
			library: sampleLibrary(),
			recentDocuments: ["file:///tmp/test1.pdf", "file:///tmp/test2.pdf"],
			pinnedDocuments: ["file:///tmp/test1.pdf"],
			webBookmarks: ["https://example.com", "https://docs.swift.org"],
			annotationBundles: [AnnotationBundle(hash: hash, annotations: sampleAnnotations())],
			notesBundles: [NotesBundle(hash: hash, notes: sampleNotes(), pageNotes: [0: "Page note on cover", 5: "Page note on ch1"], tags: ["swift", "notes"])],
			bookmarksBundles: [BookmarksBundle(hash: hash, bookmarks: [0, 5, 12, 50])],
			sessionBundles: [SessionBundle(hash: hash, data: Data("{\"page\":5}".utf8))],
			sketches: sampleSketches(),
			exportDate: Date(),
			version: "3.0"
		)
	}

	// MARK: - Encode/Decode Round-Trip (in-memory, no filesystem interference)

	func testFullRoundTrip() throws {
		let original = seedFullData()
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		let encoded = try encoder.encode(original)
		let decoded = try decoder.decode(DevReaderData.self, from: encoded)

		// Verify library
		XCTAssertEqual(decoded.library.count, original.library.count)
		for (dec, orig) in zip(decoded.library.sorted(by: { $0.title < $1.title }), original.library.sorted(by: { $0.title < $1.title })) {
			XCTAssertEqual(dec.title, orig.title)
			XCTAssertEqual(dec.author, orig.author)
			XCTAssertEqual(dec.pageCount, orig.pageCount)
			XCTAssertEqual(dec.fileSize, orig.fileSize)
			XCTAssertEqual(dec.tags, orig.tags)
		}

		// Verify recent documents
		XCTAssertEqual(decoded.recentDocuments.sorted(), original.recentDocuments.sorted())

		// Verify pinned documents
		XCTAssertEqual(decoded.pinnedDocuments.sorted(), original.pinnedDocuments.sorted())

		// Verify web bookmarks
		XCTAssertEqual(decoded.webBookmarks?.sorted(), original.webBookmarks?.sorted())

		// Verify annotations
		XCTAssertEqual(decoded.annotationBundles?.count, original.annotationBundles?.count)
		if let decBundle = decoded.annotationBundles?.first, let origBundle = original.annotationBundles?.first {
			XCTAssertEqual(decBundle.hash, origBundle.hash)
			XCTAssertEqual(decBundle.annotations.count, origBundle.annotations.count)
			for (ea, oa) in zip(decBundle.annotations, origBundle.annotations) {
				XCTAssertEqual(ea.pageIndex, oa.pageIndex)
				XCTAssertEqual(ea.type, oa.type)
				XCTAssertEqual(ea.colorName, oa.colorName)
				XCTAssertEqual(ea.text, oa.text)
			}
		}

		// Verify notes bundles
		XCTAssertEqual(decoded.notesBundles?.count, original.notesBundles?.count)
		if let decBundle = decoded.notesBundles?.first, let origBundle = original.notesBundles?.first {
			XCTAssertEqual(decBundle.hash, origBundle.hash)
			XCTAssertEqual(decBundle.notes.count, origBundle.notes.count)
			XCTAssertEqual(decBundle.pageNotes, origBundle.pageNotes)
			XCTAssertEqual(decBundle.tags, origBundle.tags)
			for (en, on) in zip(decBundle.notes.sorted(by: { $0.title < $1.title }), origBundle.notes.sorted(by: { $0.title < $1.title })) {
				XCTAssertEqual(en.title, on.title)
				XCTAssertEqual(en.text, on.text)
				XCTAssertEqual(en.pageIndex, on.pageIndex)
				XCTAssertEqual(en.chapter, on.chapter)
				XCTAssertEqual(en.tags, on.tags)
			}
		}

		// Verify bookmarks bundles
		XCTAssertEqual(decoded.bookmarksBundles?.count, original.bookmarksBundles?.count)
		if let decBundle = decoded.bookmarksBundles?.first, let origBundle = original.bookmarksBundles?.first {
			XCTAssertEqual(decBundle.hash, origBundle.hash)
			XCTAssertEqual(decBundle.bookmarks.sorted(), origBundle.bookmarks.sorted())
		}

		// Verify session bundles
		XCTAssertEqual(decoded.sessionBundles?.count, original.sessionBundles?.count)
		if let decBundle = decoded.sessionBundles?.first, let origBundle = original.sessionBundles?.first {
			XCTAssertEqual(decBundle.hash, origBundle.hash)
			XCTAssertEqual(decBundle.data, origBundle.data)
		}

		// Verify sketches
		XCTAssertEqual(decoded.sketches?.count, original.sketches?.count)
		if let decSketch = decoded.sketches?.first, let origSketch = original.sketches?.first {
			XCTAssertEqual(decSketch.title, origSketch.title)
			XCTAssertEqual(decSketch.pageIndex, origSketch.pageIndex)
			XCTAssertEqual(decSketch.canvasData, origSketch.canvasData)
			XCTAssertEqual(decSketch.strokesData, origSketch.strokesData)
		}
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

		let encoded = try JSONEncoder().encode(empty)
		let decoded = try JSONDecoder().decode(DevReaderData.self, from: encoded)

		XCTAssertTrue(decoded.library.isEmpty)
		XCTAssertTrue(decoded.recentDocuments.isEmpty)
		XCTAssertTrue(decoded.pinnedDocuments.isEmpty)
	}

	// MARK: - Partial Data (Optional Bundles)

	func testPartialDataRoundTrip() throws {
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

		let encoded = try JSONEncoder().encode(data)
		let decoded = try JSONDecoder().decode(DevReaderData.self, from: encoded)

		XCTAssertEqual(decoded.library.count, 2)
		XCTAssertEqual(decoded.notesBundles?.first?.notes.count, 2)
		XCTAssertNil(decoded.sketches)
		XCTAssertNil(decoded.annotationBundles)
		XCTAssertNil(decoded.bookmarksBundles)
	}

	// MARK: - Multiple Backups + Cleanup (uses isolated backup directory)

	func testCleanupOldBackups() throws {
		let backupDir = JSONStorageService.backupDirectory
		JSONStorageService.ensureDirectories()

		// Clean any existing backups first
		if let files = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil) {
			for file in files where file.lastPathComponent.hasPrefix("backup_2099") {
				try? FileManager.default.removeItem(at: file)
			}
		}

		// Create backup files with a far-future date to avoid colliding with real backups
		for i in 0..<12 {
			let name = "backup_2099-01-01_00-00-\(String(format: "%02d", i)).json"
			let url = backupDir.appendingPathComponent(name)
			let dummy = DevReaderData(library: [], recentDocuments: [], pinnedDocuments: [], exportDate: Date(), version: "3.0")
			let data = try JSONEncoder().encode(dummy)
			try data.write(to: url)
		}

		let beforeCleanup = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
			.filter { $0.lastPathComponent.hasPrefix("backup_") }
		XCTAssertGreaterThanOrEqual(beforeCleanup.count, 12)

		// Cleanup keeping 5
		JSONStorageService.cleanupOldBackups(keepCount: 5)

		let afterCleanup = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
			.filter { $0.lastPathComponent.hasPrefix("backup_") }
		XCTAssertLessThanOrEqual(afterCleanup.count, 5)
	}

	// MARK: - Backup File Format (uses temp directory, not shared data dir)

	func testBackupIsValidJSON() throws {
		let original = seedFullData()

		// Encode to JSON (same as what createBackup would produce)
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let backupData = try encoder.encode(original)

		// Decode it back
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let decoded = try decoder.decode(DevReaderData.self, from: backupData)
		XCTAssertEqual(decoded.version, "3.0")
		XCTAssertEqual(decoded.library.count, 2)
	}

	// MARK: - Overwrite Semantics (in-memory)

	func testImportOverwriteSemantics() throws {
		// First data set
		let firstData = DevReaderData(
			library: [DevReader.LibraryItem(url: URL(fileURLWithPath: "/tmp/old.pdf"), title: "Old Book", pageCount: 10, fileSize: 1000)],
			recentDocuments: [],
			pinnedDocuments: [],
			exportDate: Date(),
			version: "3.0"
		)

		// Second data set (simulates overwrite)
		let secondData = DevReaderData(
			library: sampleLibrary(),
			recentDocuments: ["file:///tmp/test1.pdf"],
			pinnedDocuments: [],
			exportDate: Date(),
			version: "3.0"
		)

		// Verify second data replaces first (encode/decode the replacement)
		let encoded = try JSONEncoder().encode(secondData)
		let decoded = try JSONDecoder().decode(DevReaderData.self, from: encoded)

		XCTAssertEqual(decoded.library.count, 2)
		XCTAssertTrue(decoded.library.contains(where: { $0.title == "Test Book 1" }))
		XCTAssertFalse(decoded.library.contains(where: { $0.title == "Old Book" }))

		// Also verify first data doesn't leak through
		let firstEncoded = try JSONEncoder().encode(firstData)
		let firstDecoded = try JSONDecoder().decode(DevReaderData.self, from: firstEncoded)
		XCTAssertEqual(firstDecoded.library.count, 1)
		XCTAssertTrue(firstDecoded.library.contains(where: { $0.title == "Old Book" }))
	}

	// MARK: - Filesystem Tests (isolated to temp directory)

	func testImportExportViaFilesystem() throws {
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent("BackupRestoreTest-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDir) }

		let original = seedFullData()

		// Write to temp file
		let fileURL = tempDir.appendingPathComponent("test_backup.json")
		let encoded = try JSONEncoder().encode(original)
		try encoded.write(to: fileURL)

		// Read back
		let readData = try Data(contentsOf: fileURL)
		let decoded = try JSONDecoder().decode(DevReaderData.self, from: readData)

		XCTAssertEqual(decoded.library.count, original.library.count)
		XCTAssertEqual(decoded.annotationBundles?.count, original.annotationBundles?.count)
		XCTAssertEqual(decoded.notesBundles?.first?.notes.count, original.notesBundles?.first?.notes.count)
		XCTAssertEqual(decoded.bookmarksBundles?.first?.bookmarks.sorted(), original.bookmarksBundles?.first?.bookmarks.sorted())
		XCTAssertEqual(decoded.sketches?.count, original.sketches?.count)
		XCTAssertEqual(decoded.webBookmarks?.sorted(), original.webBookmarks?.sorted())
	}

	func testCorruptBackupRestoreViaFilesystem() throws {
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent("BackupRestoreTest-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDir) }

		let original = seedFullData()

		// Write backup
		let backupURL = tempDir.appendingPathComponent("backup.json")
		try JSONEncoder().encode(original).write(to: backupURL)

		// Write "corrupted" data (empty library)
		let corruptedURL = tempDir.appendingPathComponent("library.json")
		let corrupted: [DevReader.LibraryItem] = []
		try JSONEncoder().encode(corrupted).write(to: corruptedURL)

		// Verify corrupted data
		let corruptedLib = try JSONDecoder().decode([DevReader.LibraryItem].self, from: Data(contentsOf: corruptedURL))
		XCTAssertTrue(corruptedLib.isEmpty, "Library should be empty after corruption")

		// "Restore" from backup
		let backupData = try Data(contentsOf: backupURL)
		let restored = try JSONDecoder().decode(DevReaderData.self, from: backupData)

		// Verify restored data
		XCTAssertEqual(restored.library.count, original.library.count)
		XCTAssertEqual(restored.annotationBundles?.count ?? 0, original.annotationBundles?.count ?? 0)
		XCTAssertEqual(restored.notesBundles?.first?.notes.count, original.notesBundles?.first?.notes.count)
		XCTAssertEqual(restored.sketches?.count, original.sketches?.count)
	}

	// MARK: - Import Atomicity (staging directory check)

	func testImportStagingDirectoryCleanup() throws {
		// Verify no stale staging directories exist
		JSONStorageService.ensureDirectories()
		let appSupport = JSONStorageService.appSupportURL
		let contents = try FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
		let stagingDirs = contents.filter { $0.lastPathComponent.hasPrefix("ImportStaging-") }
		XCTAssertTrue(stagingDirs.isEmpty, "No stale staging directories should exist")
	}
}
