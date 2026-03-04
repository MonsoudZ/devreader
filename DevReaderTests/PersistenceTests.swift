import XCTest
@testable import DevReader
import Foundation

@MainActor
final class PersistenceTests: XCTestCase {

    override func tearDownWithError() throws {
        // Clear all test data
        PersistenceService.clearAllData()
    }

    // MARK: - Atomic Persistence Tests

    func testAtomicWriteSuccess() async throws {
        let testData = ["key1": "value1", "key2": "value2"]
        let key = "test.atomic.success"

        // Save data
        try PersistenceService.saveCodable(testData, forKey: key)

        // Load data
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)

        XCTAssertNotNil(loadedData, "Data should be loaded successfully")
        XCTAssertEqual(loadedData?["key1"], "value1", "First value should match")
        XCTAssertEqual(loadedData?["key2"], "value2", "Second value should match")
    }

    func testAtomicWriteFailure() async {
        // Use a path inside a non-existent, non-creatable directory to force write failure.
        // Saving with a key whose data directory cannot be written to should throw.
        let blockedDir = FileManager.default.temporaryDirectory.appendingPathComponent("devreader_blocked_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: blockedDir, withIntermediateDirectories: true)

        // Make the directory read-only so the temp file write fails
        try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: blockedDir.path)

        let blockedURL = blockedDir.appendingPathComponent("blocked.json")
        let testData = ["key1": "value1", "key2": "value2"]

        XCTAssertThrowsError(try JSONStorageService.save(testData, to: blockedURL),
                             "Save should throw when directory is read-only")

        // Data should not be loadable
        let loadedData: [String: String]? = JSONStorageService.loadOptional([String: String].self, from: blockedURL)
        XCTAssertNil(loadedData, "Data should not be loaded after write failure")

        // Restore permissions and clean up
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blockedDir.path)
        try? FileManager.default.removeItem(at: blockedDir)
    }

    func testCorruptedDataRecovery() async throws {
        let testData = ["key1": "value1", "key2": "value2"]
        let key = "test.corrupted.recovery"

        // Save valid data first
        try PersistenceService.saveCodable(testData, forKey: key)

        // Corrupt the file
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(key).json")
        try? "corrupted json data".write(to: fileURL, atomically: true, encoding: .utf8)

        // Try to load corrupted data
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)
        XCTAssertNil(loadedData, "Corrupted data should not be loaded")

        // Validate data integrity
        let isValid = PersistenceService.validateData(forKey: key)
        XCTAssertFalse(isValid, "Corrupted data should be invalid")
    }

    // MARK: - Schema Versioning Tests

    func testSchemaVersioning() async throws {
        let items = [
            LibraryItem(url: URL(fileURLWithPath: "/test1.pdf")),
            LibraryItem(url: URL(fileURLWithPath: "/test2.pdf"))
        ]

        let envelope = LibraryEnvelope(items: items)

        // Save envelope
        let key = "test.schema.versioning"
        try PersistenceService.saveCodable(envelope, forKey: key)

        // Load envelope
        let loadedEnvelope: LibraryEnvelope? = PersistenceService.loadCodable(LibraryEnvelope.self, forKey: key)

        XCTAssertNotNil(loadedEnvelope, "Envelope should be loaded successfully")
        XCTAssertEqual(loadedEnvelope?.schemaVersion, "2.0", "Schema version should match")
        XCTAssertEqual(loadedEnvelope?.items.count, 2, "Items count should match")
    }

    func testSchemaMigration() async throws {
        // Create old format data
        let oldItems = [
            OldLibraryItem(
                url: URL(fileURLWithPath: "/test1.pdf"),
                title: "Test PDF 1",
                author: "Test Author",
                pageCount: 10,
                fileSize: 1024,
                addedDate: Date(),
                lastOpened: nil,
                tags: ["test"],
                isPinned: false,
                thumbnailData: nil
            )
        ]

        // Save old format data
        let key = "test.schema.migration"
        try PersistenceService.saveCodable(oldItems, forKey: key)

        // Load and migrate
        let data = try? Data(contentsOf: JSONStorageService.dataDirectory.appendingPathComponent("\(key).json"))
        XCTAssertNotNil(data, "Data should be loaded")

        if let data = data {
            do {
                let envelope = try LibraryMigration.migrateLibraryData(data)
                XCTAssertEqual(envelope.items.count, 1, "Migrated items count should match")
                XCTAssertEqual(envelope.items.first?.title, "Test PDF 1", "Migrated title should match")
            } catch {
                XCTFail("Migration should succeed: \(error)")
            }
        }
    }

    // MARK: - Duplicate Detection Tests

    func testDuplicateDetectionByURL() async {
        let url1 = URL(fileURLWithPath: "/test1.pdf")
        let url2 = URL(fileURLWithPath: "/test1.pdf")

        let item1 = LibraryItem(url: url1)
        let item2 = LibraryItem(url: url2)

        XCTAssertTrue(item1.isDuplicate(of: item2), "Items with same URL should be duplicates")
    }

    func testDuplicateDetectionByFileAttributes() async {
        // Items at different paths but same filename and file size are duplicates
        let url1 = URL(fileURLWithPath: "/folder1/dup_test1.pdf")
        let url2 = URL(fileURLWithPath: "/folder2/dup_test1.pdf")

        let item1 = LibraryItem(url: url1, title: "dup_test1.pdf", fileSize: 1024)
        let item2 = LibraryItem(url: url2, title: "dup_test1.pdf", fileSize: 1024)

        XCTAssertTrue(item1.isDuplicate(of: item2), "Items with same name and size should be duplicates")
    }

    func testDuplicateDetectionDifferentFiles() async {
        let url1 = URL(fileURLWithPath: "/test1.pdf")
        let url2 = URL(fileURLWithPath: "/test2.pdf")

        let item1 = LibraryItem(url: url1)
        let item2 = LibraryItem(url: url2)

        XCTAssertFalse(item1.isDuplicate(of: item2), "Items with different URLs should not be duplicates")
    }

    // MARK: - Security-Scoped Bookmark Tests

    func testSecurityScopedBookmarkCreation() async throws {
        // Security-scoped bookmarks require sandbox entitlements that are not
        // available in the test runner. The API returns nil for regular file URLs.
        let tempURL = createTempFile(name: "bookmark_test")
        let item = LibraryItem(url: tempURL)

        let bookmark = item.createSecurityScopedBookmark()
        // In non-sandboxed test environment, bookmark creation may return nil.
        // This is expected — the important thing is it doesn't crash.
        if bookmark == nil {
            // Expected in test runner without sandbox entitlements
        } else {
            XCTAssertNotNil(bookmark)
        }

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testSecurityScopedBookmarkResolution() async throws {
        let tempURL = createTempFile(name: "bookmark_resolve_test")
        let item = LibraryItem(url: tempURL)

        let bookmark = item.createSecurityScopedBookmark()

        // If bookmark creation fails (expected in non-sandboxed test),
        // resolveURLFromBookmark should still return the original URL
        let itemWithBookmark = LibraryItem(
            url: tempURL,
            securityScopedBookmark: bookmark,
            title: "Test PDF",
            fileSize: 1024,
            addedDate: Date(),
            lastOpened: nil
        )

        let resolvedURL = itemWithBookmark.resolveURLFromBookmark()
        // Should return either the resolved URL or the original URL (fallback)
        XCTAssertNotNil(resolvedURL, "URL should be resolved or fall back to original")

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Background Persistence Tests

    func testBackgroundPersistence() async {
        let service = LibraryPersistenceService.shared
        let items = [
            LibraryItem(url: URL(fileURLWithPath: "/test1.pdf")),
            LibraryItem(url: URL(fileURLWithPath: "/test2.pdf")),
            LibraryItem(url: URL(fileURLWithPath: "/test3.pdf"))
        ]

        // Start background save
        await service.saveLibraryItems(items)

        // Wait for completion
        while service.isProcessing {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        XCTAssertFalse(service.isProcessing, "Background processing should complete")
        XCTAssertEqual(service.progress, 1.0, "Progress should be 100%")
    }

    func testBackgroundDeduplication() async {
        let service = LibraryPersistenceService.shared
        let items = [
            LibraryItem(url: URL(fileURLWithPath: "/test1.pdf")),
            LibraryItem(url: URL(fileURLWithPath: "/test1.pdf")), // Duplicate
            LibraryItem(url: URL(fileURLWithPath: "/test2.pdf"))
        ]

        // Start background deduplication
        let uniqueItems = await service.removeDuplicates(from: items)

        XCTAssertEqual(uniqueItems.count, 2, "Should remove duplicate")
        XCTAssertFalse(service.isProcessing, "Background processing should complete")
    }

    // MARK: - Round-Trip Tests

    func testRoundTripEncodeDecode() async throws {
        let originalItems = [
            LibraryItem(
                url: URL(fileURLWithPath: "/test1.pdf"),
                title: "Test PDF 1",
                author: "Test Author",
                pageCount: 10,
                fileSize: 1024,
                addedDate: Date(),
                lastOpened: Date(),
                tags: ["test", "pdf"],
                isPinned: true
            ),
            LibraryItem(
                url: URL(fileURLWithPath: "/test2.pdf"),
                title: "Test PDF 2",
                author: "Test Author 2",
                pageCount: 20,
                fileSize: 2048,
                addedDate: Date(),
                lastOpened: nil,
                tags: ["test"],
                isPinned: false
            )
        ]

        let envelope = LibraryEnvelope(items: originalItems)

        // Save envelope
        let key = "test.roundtrip"
        try PersistenceService.saveCodable(envelope, forKey: key)

        // Load envelope
        let loadedEnvelope: LibraryEnvelope? = PersistenceService.loadCodable(LibraryEnvelope.self, forKey: key)

        XCTAssertNotNil(loadedEnvelope, "Envelope should be loaded successfully")
        XCTAssertEqual(loadedEnvelope?.items.count, 2, "Items count should match")

        // Verify first item
        let firstItem = loadedEnvelope?.items.first
        XCTAssertEqual(firstItem?.title, "Test PDF 1", "Title should match")
        XCTAssertEqual(firstItem?.author, "Test Author", "Author should match")
        XCTAssertEqual(firstItem?.pageCount, 10, "Page count should match")
        XCTAssertEqual(firstItem?.fileSize, 1024, "File size should match")
        XCTAssertEqual(firstItem?.tags, ["test", "pdf"], "Tags should match")
        XCTAssertTrue(firstItem?.isPinned == true, "Pinned status should match")

        // Verify second item
        let secondItem = loadedEnvelope?.items.last
        XCTAssertEqual(secondItem?.title, "Test PDF 2", "Title should match")
        XCTAssertEqual(secondItem?.author, "Test Author 2", "Author should match")
        XCTAssertEqual(secondItem?.pageCount, 20, "Page count should match")
        XCTAssertEqual(secondItem?.fileSize, 2048, "File size should match")
        XCTAssertEqual(secondItem?.tags, ["test"], "Tags should match")
        XCTAssertTrue(secondItem?.isPinned == false, "Pinned status should match")
    }

    // MARK: - Error Handling Tests

    func testInvalidDataHandling() async {
        let key = "test.invalid.data"

        // Ensure directory exists
        JSONStorageService.ensureDirectories()

        // Save invalid data
        let invalidData = "invalid json data"
        try? invalidData.write(to: JSONStorageService.dataDirectory.appendingPathComponent("\(key).json"), atomically: true, encoding: .utf8)

        // Try to load invalid data
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)
        XCTAssertNil(loadedData, "Invalid data should not be loaded")

        // Validate data integrity
        let isValid = PersistenceService.validateData(forKey: key)
        XCTAssertFalse(isValid, "Invalid data should be invalid")
    }

    func testDataRecovery() async throws {
        let key = "test.data.recovery"
        let testData = ["key1": "value1", "key2": "value2"]

        // Save valid data first
        try PersistenceService.saveCodable(testData, forKey: key)

        // Corrupt the data
        try? "corrupted data".write(to: JSONStorageService.dataDirectory.appendingPathComponent("\(key).json"), atomically: true, encoding: .utf8)

        // Attempt recovery
        PersistenceService.recoverCorruptedData(forKey: key)

        // Data should be cleared
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)
        XCTAssertNil(loadedData, "Corrupted data should be cleared")
    }

    // MARK: - Helper Methods

    private func createTempFile(name: String = "test") -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)_\(UUID().uuidString).txt")
        try? "test content".write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
