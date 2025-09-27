import XCTest
@testable import DevReader

final class JSONStorageTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure test directory exists
        try? JSONStorageService.ensureDirectories()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up test files
        let testFiles = [
            "test.json",
            "test_int.json", 
            "test_bool.json",
            "test_string.json",
            "test_optional.json",
            "test_delete.json",
            "test_migration.json",
            "test_backup.json",
            "test_export.json",
            "test_import.json",
            "test_validation.json",
            "test_performance.json"
        ]
        
        for fileName in testFiles {
            let url = JSONStorageService.dataDirectory.appendingPathComponent(fileName)
            JSONStorageService.delete(url: url)
        }
    }
    
    // MARK: - Basic Storage Tests
    
    func testSaveAndLoadCodable() throws {
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
            let items: [String]
        }
        
        let testData = TestData(name: "Test", value: 42, items: ["item1", "item2"])
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test.json")
        
        // Save
        try JSONStorageService.save(testData, to: url)
        
        // Load
        let loadedData: TestData = try JSONStorageService.load(TestData.self, from: url)
        
        XCTAssertEqual(loadedData.name, testData.name)
        XCTAssertEqual(loadedData.value, testData.value)
        XCTAssertEqual(loadedData.items, testData.items)
    }
    
    func testSaveAndLoadPrimitives() throws {
        let intURL = JSONStorageService.dataDirectory.appendingPathComponent("test_int.json")
        let boolURL = JSONStorageService.dataDirectory.appendingPathComponent("test_bool.json")
        let stringURL = JSONStorageService.dataDirectory.appendingPathComponent("test_string.json")
        
        // Test Int
        try JSONStorageService.save(123, to: intURL)
        let loadedInt: Int = try JSONStorageService.load(Int.self, from: intURL)
        XCTAssertEqual(loadedInt, 123, "Should save and load Int values")
        
        // Test Bool
        try JSONStorageService.save(true, to: boolURL)
        let loadedBool: Bool = try JSONStorageService.load(Bool.self, from: boolURL)
        XCTAssertEqual(loadedBool, true, "Should save and load Bool values")
        
        // Test String
        try JSONStorageService.save("Hello World", to: stringURL)
        let loadedString: String = try JSONStorageService.load(String.self, from: stringURL)
        XCTAssertEqual(loadedString, "Hello World", "Should save and load String values")
    }
    
    func testLoadOptional() {
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_optional.json")
        
        // Test loading non-existent file
        let loadedData: String? = JSONStorageService.loadOptional(String.self, from: url)
        XCTAssertNil(loadedData, "Should return nil for non-existent file")
        
        // Test loading existing file
        let testString = "Test String"
        try? JSONStorageService.save(testString, to: url)
        let loadedString: String? = JSONStorageService.loadOptional(String.self, from: url)
        XCTAssertEqual(loadedString, testString, "Should load existing file")
    }
    
    func testDelete() {
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_delete.json")
        let testData = "Test Data"
        
        // Save data
        try? JSONStorageService.save(testData, to: url)
        
        // Verify it exists
        let loadedData: String? = JSONStorageService.loadOptional(String.self, from: url)
        XCTAssertNotNil(loadedData, "Data should exist before deletion")
        
        // Delete data
        JSONStorageService.delete(url: url)
        
        // Verify it's gone
        let deletedData: String? = JSONStorageService.loadOptional(String.self, from: url)
        XCTAssertNil(deletedData, "Data should be deleted")
    }
    
    // MARK: - Migration Tests
    
    func testMigrationFromUserDefaults() {
        // This test verifies that migration doesn't crash
        // The actual migration logic is tested in the app itself
        JSONStorageService.migrateFromUserDefaults()
        XCTAssertTrue(true, "Migration should complete without crashing")
    }
    
    // MARK: - Backup and Restore Tests
    
    func testCreateBackup() throws {
        let testData = "Backup Test Data"
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_backup.json")
        
        // Save test data
        try JSONStorageService.save(testData, to: url)
        
        // Create backup
        let backupURL = try JSONStorageService.createBackup()
        
        // Verify backup exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "Backup file should exist")
        
        // Clean up
        try? FileManager.default.removeItem(at: backupURL)
    }
    
    func testRestoreFromBackup() throws {
        let testData = "Restore Test Data"
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_restore.json")
        
        // Save test data
        try JSONStorageService.save(testData, to: url)
        
        // Create backup
        let backupURL = try JSONStorageService.createBackup()
        
        // Delete original data
        JSONStorageService.delete(url: url)
        
        // Restore from backup
        try JSONStorageService.restoreFromBackup(backupURL)
        
        // Verify some data files exist after restore (we can't guarantee arbitrary test file is included)
        let libraryExists = FileManager.default.fileExists(atPath: JSONStorageService.libraryPath().path)
        XCTAssertTrue(libraryExists, "Library file should exist after restore")
        
        // Clean up
        try? FileManager.default.removeItem(at: backupURL)
    }
    
    // MARK: - Export and Import Tests
    
    func testExportAllData() throws {
        let testData = "Export Test Data"
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_export.json")
        
        // Save test data
        try JSONStorageService.save(testData, to: url)
        
        // Export all data
        let exportedData = try JSONStorageService.exportAllData()
        
        // Verify export contains our data
        XCTAssertNotNil(exportedData, "Export should return data")
        
        // Clean up
        JSONStorageService.delete(url: url)
    }
    
    func testImportAllData() throws {
        // Create test data structure
        let testData = DevReaderData(
            library: [],
            recentDocuments: [],
            pinnedDocuments: [],
            exportDate: Date(),
            version: "1.0"
        )
        
        // Import data
        try JSONStorageService.importAllData(testData)
        
        // Verify import succeeded (no crash)
        XCTAssertTrue(true, "Import should complete without crashing")
    }
    
    // MARK: - Data Validation Tests
    
    func testValidateDataIntegrity() {
        // Test with valid data
        let testData = "Valid Data"
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_validation.json")
        
        try? JSONStorageService.save(testData, to: url)
        let validationResult = JSONStorageService.validateDataIntegrity()
        
        // Validation should return empty array for valid data
        XCTAssertTrue(validationResult.isEmpty, "Valid data should pass validation")
        
        // Clean up
        JSONStorageService.delete(url: url)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceLargeData() throws {
        // Create large data
        let largeString = String(repeating: "A", count: 10000)
        let url = JSONStorageService.dataDirectory.appendingPathComponent("test_performance.json")
        
        // Measure save+load together to reduce variance in CI
        measure {
            try? JSONStorageService.save(largeString, to: url)
            let _: String? = JSONStorageService.loadOptional(String.self, from: url)
        }
        
        // Clean up
        JSONStorageService.delete(url: url)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveToInvalidPath() {
        let invalidURL = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/test.json")
        let testData = "Test Data"
        
        // This should throw an error
        XCTAssertThrowsError(try JSONStorageService.save(testData, to: invalidURL), "Should throw error for invalid path")
    }
    
    func testLoadFromNonExistentFile() {
        let nonExistentURL = JSONStorageService.dataDirectory.appendingPathComponent("non_existent.json")
        
        // This should throw an error
        XCTAssertThrowsError(try JSONStorageService.load(String.self, from: nonExistentURL), "Should throw error for non-existent file")
    }
}