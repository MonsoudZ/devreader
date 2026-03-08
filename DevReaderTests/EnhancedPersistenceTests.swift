import XCTest
@testable import DevReader
import Foundation

@MainActor
final class EnhancedPersistenceTests: XCTestCase {
    
    var persistenceService: EnhancedPersistenceService!
    var mockPersistenceService: MockNotesPersistenceService!
    var notesStore: NotesStore!
    
    override func setUpWithError() throws {
        persistenceService = EnhancedPersistenceService.shared
        mockPersistenceService = MockNotesPersistenceService()
        notesStore = NotesStore(persistenceService: mockPersistenceService)
    }
    
    override func tearDownWithError() throws {
        // Clear all test data
        persistenceService.clearAllData()
    }
    
    // MARK: - Collision Prevention Tests
    
    func testKeyGenerationPreventsCollisions() async {
        // Create two PDFs with same name in different subdirectories
        let subdir1 = FileManager.default.temporaryDirectory.appendingPathComponent("dir1", isDirectory: true)
        let subdir2 = FileManager.default.temporaryDirectory.appendingPathComponent("dir2", isDirectory: true)
        try? FileManager.default.createDirectory(at: subdir1, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: subdir2, withIntermediateDirectories: true)

        let pdf1 = subdir1.appendingPathComponent("book.pdf")
        let pdf2 = subdir2.appendingPathComponent("book.pdf")
        try? "Content 1".write(to: pdf1, atomically: true, encoding: .utf8)
        try? "Content 2".write(to: pdf2, atomically: true, encoding: .utf8)

        let key1 = persistenceService.generateKey("test.notes", for: pdf1)
        let key2 = persistenceService.generateKey("test.notes", for: pdf2)

        XCTAssertNotEqual(key1, key2, "Keys should be different for same-named PDFs in different locations")

        // Clean up
        try? FileManager.default.removeItem(at: subdir1)
        try? FileManager.default.removeItem(at: subdir2)
    }
    
    func testKeyGenerationUsesContentFingerprint() async {
        let pdf = makeTempFile(named: "test_attrs.pdf", content: "Original content")
        let key1 = persistenceService.generateKey("test.notes", for: pdf)

        // Modify file content — key SHOULD change (content-based fingerprinting)
        try? "Modified content".write(to: pdf, atomically: true, encoding: .utf8)
        let key2 = persistenceService.generateKey("test.notes", for: pdf)

        XCTAssertNotEqual(key1, key2, "Key should change when file content changes (content-based fingerprinting)")

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    func testSamePDFGeneratesSameKey() async {
        let pdf = makeTempFile(named: "test.pdf", content: "Content")
        let key1 = persistenceService.generateKey("test.notes", for: pdf)
        let key2 = persistenceService.generateKey("test.notes", for: pdf)
        
        XCTAssertEqual(key1, key2, "Same PDF should generate same key")
        
        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    // MARK: - Atomic Write Tests
    
    func testAtomicWriteSuccess() async {
        let testData = ["key1": "value1", "key2": "value2"]
        let pdf = makeTempFile(named: "test.pdf", content: "Content")
        
        do {
            try persistenceService.saveCodable(testData, forKey: "test.atomic", url: pdf)
            let loadedData: [String: String]? = persistenceService.loadCodable([String: String].self, forKey: "test.atomic", url: pdf)
            
            XCTAssertNotNil(loadedData, "Data should be loaded successfully")
            XCTAssertEqual(loadedData?["key1"], "value1", "First value should match")
            XCTAssertEqual(loadedData?["key2"], "value2", "Second value should match")
        } catch {
            XCTFail("Atomic write should succeed: \(error)")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    func testAtomicWriteWithCorruption() async {
        let testData = ["key1": "value1", "key2": "value2"]
        let pdf = makeTempFile(named: "test.pdf", content: "Content")

        do {
            try persistenceService.saveCodable(testData, forKey: "test.corruption", url: pdf)

            // Corrupt the file using the actual generated key
            let actualKey = persistenceService.generateKey("test.corruption", for: pdf)
            let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(actualKey).json")
            try? "corrupted data".write(to: fileURL, atomically: true, encoding: .utf8)

            // Try to load corrupted data
            let loadedData: [String: String]? = persistenceService.loadCodable([String: String].self, forKey: "test.corruption", url: pdf)
            XCTAssertNil(loadedData, "Corrupted data should not be loaded")

            // Validate data integrity
            let isValid = persistenceService.validateData(forKey: "test.corruption", url: pdf)
            XCTAssertFalse(isValid, "Corrupted data should be invalid")

        } catch {
            XCTFail("Test setup should succeed: \(error)")
        }

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    // MARK: - NotesStore Integration Tests
    
    func testNotesStoreWithMockPersistence() async {
        let pdf = makeTempFile(named: "test_mock.pdf", content: "Content")

        // Set current PDF
        notesStore.setCurrentPDF(pdf)
        await notesStore.loadingTask?.value

        // Add a note
        let note = NoteItem(text: "Test note", pageIndex: 1, chapter: "Test Chapter")
        notesStore.add(note)

        // Poll for debounced persistence to complete
        await waitUntil(timeout: 2.0) { [mock = self.mockPersistenceService!] in !mock.lastSavedNotes.isEmpty }

        // Verify note was saved
        XCTAssertEqual(mockPersistenceService.lastSavedNotes.count, 1, "Note should be saved")
        XCTAssertEqual(mockPersistenceService.lastSavedNotes.first?.text, "Test note", "Note text should match")

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    func testNotesStoreHandlesPersistenceErrors() async {
        let pdf = makeTempFile(named: "test.pdf", content: "Content")
        
        // Configure mock to throw error
        mockPersistenceService.shouldThrowError = true

        // Set current PDF
        notesStore.setCurrentPDF(pdf)
        await notesStore.loadingTask?.value

        // Add a note (should not crash despite persistence error)
        let note = NoteItem(text: "Test note", pageIndex: 1, chapter: "Test Chapter")
        notesStore.add(note)
        
        // Verify note was still added to store (even if persistence failed)
        XCTAssertEqual(notesStore.items.count, 1, "Note should be added to store")
        
        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    func testNotesStoreSeparatesNotesByPDF() async {
        let pdf1 = makeTempFile(named: "book1.pdf", content: "Content 1")
        let pdf2 = makeTempFile(named: "book2.pdf", content: "Content 2")
        
        // Add note to first PDF
        notesStore.setCurrentPDF(pdf1)
        await notesStore.loadingTask?.value
        let note1 = NoteItem(text: "Note for book 1", pageIndex: 1, chapter: "Chapter 1")
        notesStore.add(note1)

        // Add note to second PDF
        notesStore.setCurrentPDF(pdf2)
        await notesStore.loadingTask?.value
        let note2 = NoteItem(text: "Note for book 2", pageIndex: 1, chapter: "Chapter 1")
        notesStore.add(note2)

        // Switch back to first PDF
        notesStore.setCurrentPDF(pdf1)
        await notesStore.loadingTask?.value

        // Verify only first PDF's notes are loaded
        XCTAssertEqual(notesStore.items.count, 1, "Should have 1 note for first PDF")
        XCTAssertEqual(notesStore.items.first?.text, "Note for book 1", "Should have correct note")
        
        // Clean up
        try? FileManager.default.removeItem(at: pdf1)
        try? FileManager.default.removeItem(at: pdf2)
    }
    
    func testTagsPersistenceSync() async {
        let pdf = makeTempFile(named: "test_tags.pdf", content: "Content")
        notesStore.setCurrentPDF(pdf)
        await notesStore.loadingTask?.value

        // Add a note with tags
        let note = NoteItem(text: "Test note", pageIndex: 1, chapter: "Test Chapter")
        notesStore.add(note)
        notesStore.addTag("important", to: note)
        notesStore.addTag("review", to: note)

        // Poll for debounced persistence to complete
        await waitUntil(timeout: 2.0) { [mock = self.mockPersistenceService!] in mock.lastSavedTags.count >= 2 }

        // Verify tags were saved
        XCTAssertEqual(mockPersistenceService.lastSavedTags.count, 2, "Should save 2 tags")
        XCTAssertTrue(mockPersistenceService.lastSavedTags.contains("important"), "Should contain 'important' tag")
        XCTAssertTrue(mockPersistenceService.lastSavedTags.contains("review"), "Should contain 'review' tag")

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
    // MARK: - Data Recovery Tests
    
    func testDataRecovery() async {
        let pdf = makeTempFile(named: "test.pdf", content: "Content")

        // Save some data
        let testData = ["key1": "value1"]
        try? persistenceService.saveCodable(testData, forKey: "test.recovery", url: pdf)

        // Corrupt the data using the actual generated key
        let actualKey = persistenceService.generateKey("test.recovery", for: pdf)
        let fileURL = JSONStorageService.dataDirectory.appendingPathComponent("\(actualKey).json")
        try? "corrupted data".write(to: fileURL, atomically: true, encoding: .utf8)

        // Attempt recovery
        persistenceService.recoverCorruptedData(forKey: "test.recovery", url: pdf)

        // Verify data was cleared
        let loadedData: [String: String]? = persistenceService.loadCodable([String: String].self, forKey: "test.recovery", url: pdf)
        XCTAssertNil(loadedData, "Corrupted data should be cleared after recovery")

        // Clean up
        try? FileManager.default.removeItem(at: pdf)
    }
    
}
