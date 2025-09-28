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
    
    func testAtomicWriteSuccess() async {
        let testData = ["key1": "value1", "key2": "value2"]
        let key = "test.atomic.success"
        
        // Save data
        PersistenceService.saveCodable(testData, forKey: key)
        
        // Load data
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)
        
        XCTAssertNotNil(loadedData, "Data should be loaded successfully")
        XCTAssertEqual(loadedData?["key1"], "value1", "First value should match")
        XCTAssertEqual(loadedData?["key2"], "value2", "Second value should match")
    }
    
    func testAtomicWriteFailure() async {
        let testData = ["key1": "value1", "key2": "value2"]
        let key = "test.atomic.failure"
        
        // Create a directory with the same name as the file to cause write failure
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(key).json")
        try? FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        
        // Save data (should handle failure gracefully)
        PersistenceService.saveCodable(testData, forKey: key)
        
        // Data should not be corrupted
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)
        XCTAssertNil(loadedData, "Data should not be loaded after write failure")
        
        // Clean up
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func testCorruptedDataRecovery() async {
        let testData = ["key1": "value1", "key2": "value2"]
        let key = "test.corrupted.recovery"
        
        // Save valid data first
        PersistenceService.saveCodable(testData, forKey: key)
        
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
    
    func testSchemaVersioning() async {
        let items = [
            LibraryItem(url: URL(fileURLWithPath: "/test1.pdf")),
            LibraryItem(url: URL(fileURLWithPath: "/test2.pdf"))
        ]
        
        let envelope = LibraryEnvelope(items: items)
        
        // Save envelope
        let key = "test.schema.versioning"
        PersistenceService.saveCodable(envelope, forKey: key)
        
        // Load envelope
        let loadedEnvelope: LibraryEnvelope? = PersistenceService.loadCodable(LibraryEnvelope.self, forKey: key)
        
        XCTAssertNotNil(loadedEnvelope, "Envelope should be loaded successfully")
        XCTAssertEqual(loadedEnvelope?.schemaVersion, "2.0", "Schema version should match")
        XCTAssertEqual(loadedEnvelope?.items.count, 2, "Items count should match")
    }
    
    func testSchemaMigration() async {
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
        PersistenceService.saveCodable(oldItems, forKey: key)
        
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
        let tempURL1 = createTempFile()
        let tempURL2 = createTempFile()
        
        // Copy file to create identical content
        try? FileManager.default.copyItem(at: tempURL1, to: tempURL2)
        
        let item1 = LibraryItem(url: tempURL1)
        let item2 = LibraryItem(url: tempURL2)
        
        XCTAssertTrue(item1.isDuplicate(of: item2), "Items with identical content should be duplicates")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL1)
        try? FileManager.default.removeItem(at: tempURL2)
    }
    
    func testDuplicateDetectionDifferentFiles() async {
        let url1 = URL(fileURLWithPath: "/test1.pdf")
        let url2 = URL(fileURLWithPath: "/test2.pdf")
        
        let item1 = LibraryItem(url: url1)
        let item2 = LibraryItem(url: url2)
        
        XCTAssertFalse(item1.isDuplicate(of: item2), "Items with different URLs should not be duplicates")
    }
    
    // MARK: - Security-Scoped Bookmark Tests
    
    func testSecurityScopedBookmarkCreation() async {
        let tempURL = createTempFile()
        let item = LibraryItem(url: tempURL)
        
        let bookmark = item.createSecurityScopedBookmark()
        XCTAssertNotNil(bookmark, "Security-scoped bookmark should be created")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testSecurityScopedBookmarkResolution() async {
        let tempURL = createTempFile()
        let item = LibraryItem(url: tempURL)
        
        let bookmark = item.createSecurityScopedBookmark()
        XCTAssertNotNil(bookmark, "Security-scoped bookmark should be created")
        
        // Create new item with bookmark
        let itemWithBookmark = LibraryItem(
            url: tempURL,
            securityScopedBookmark: bookmark,
            title: "Test PDF",
            fileSize: 1024,
            addedDate: Date(),
            lastOpened: nil
        )
        
        let resolvedURL = itemWithBookmark.resolveURLFromBookmark()
        XCTAssertNotNil(resolvedURL, "URL should be resolved from bookmark")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Background Persistence Tests
    
    func testBackgroundPersistence() async {
        let service = BackgroundPersistenceService.shared
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
        let service = BackgroundPersistenceService.shared
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
    
    func testRoundTripEncodeDecode() async {
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
        PersistenceService.saveCodable(envelope, forKey: key)
        
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
    
    func testDataRecovery() async {
        let key = "test.data.recovery"
        let testData = ["key1": "value1", "key2": "value2"]
        
        // Save valid data first
        PersistenceService.saveCodable(testData, forKey: key)
        
        // Corrupt the data
        try? "corrupted data".write(to: JSONStorageService.dataDirectory.appendingPathComponent("\(key).json"), atomically: true, encoding: .utf8)
        
        // Attempt recovery
        PersistenceService.recoverCorruptedData(forKey: key)
        
        // Data should be cleared
        let loadedData: [String: String]? = PersistenceService.loadCodable([String: String].self, forKey: key)
        XCTAssertNil(loadedData, "Corrupted data should be cleared")
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile() -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).txt")
        try? "test content".write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
