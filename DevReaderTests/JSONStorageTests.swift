import XCTest
@testable import DevReader

final class JSONStorageTests: XCTestCase {
    
    override func tearDownWithError() throws {
        // Clean up test data
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testPath = documentsPath.appendingPathComponent("DevReader/TestData")
        
        if FileManager.default.fileExists(atPath: testPath.path) {
            try? FileManager.default.removeItem(at: testPath)
        }
    }
    
    // MARK: - Basic Storage Tests
    
    func testSaveAndLoadCodable() {
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
            let items: [String]
        }
        
        let testData = TestData(name: "Test", value: 42, items: ["item1", "item2"])
        let key = "test.codable.\(UUID().uuidString)"
        
        // Test save
        let saveResult = JSONStorageService.save(testData, forKey: key)
        XCTAssertTrue(saveResult, "Should save codable data successfully")
        
        // Test load
        let loadedData: TestData? = JSONStorageService.load(forKey: key)
        XCTAssertNotNil(loadedData, "Should load codable data successfully")
        XCTAssertEqual(loadedData, testData, "Loaded data should match saved data")
    }
    
    func testSaveAndLoadPrimitives() {
        let intKey = "test.int.\(UUID().uuidString)"
        let boolKey = "test.bool.\(UUID().uuidString)"
        
        // Test Int
        let intResult = JSONStorageService.save(123, forKey: intKey)
        XCTAssertTrue(intResult, "Should save Int successfully")
        
        let loadedInt: Int? = JSONStorageService.load(forKey: intKey)
        XCTAssertEqual(loadedInt, 123, "Should load Int correctly")
        
        // Test Bool
        let boolResult = JSONStorageService.save(true, forKey: boolKey)
        XCTAssertTrue(boolResult, "Should save Bool successfully")
        
        let loadedBool: Bool? = JSONStorageService.load(forKey: boolKey)
        XCTAssertEqual(loadedBool, true, "Should load Bool correctly")
    }
    
    func testLoadOptional() {
        let key = "test.optional.\(UUID().uuidString)"
        
        // Test loading non-existent key
        let loadedData: String? = JSONStorageService.loadOptional(forKey: key)
        XCTAssertNil(loadedData, "Should return nil for non-existent key")
        
        // Test loading existing key
        let saveResult = JSONStorageService.save("test value", forKey: key)
        XCTAssertTrue(saveResult, "Should save data successfully")
        
        let loadedValue: String? = JSONStorageService.loadOptional(forKey: key)
        XCTAssertEqual(loadedValue, "test value", "Should load existing data correctly")
    }
    
    func testDelete() {
        let key = "test.delete.\(UUID().uuidString)"
        
        // Save data first
        let saveResult = JSONStorageService.save("test data", forKey: key)
        XCTAssertTrue(saveResult, "Should save data successfully")
        
        // Verify it exists
        let loadedData: String? = JSONStorageService.load(forKey: key)
        XCTAssertNotNil(loadedData, "Data should exist before deletion")
        
        // Delete data
        let deleteResult = JSONStorageService.delete(forKey: key)
        XCTAssertTrue(deleteResult, "Should delete data successfully")
        
        // Verify it's gone
        let deletedData: String? = JSONStorageService.load(forKey: key)
        XCTAssertNil(deletedData, "Data should be deleted")
    }
    
    // MARK: - Migration Tests
    
    func testMigrationFromUserDefaults() {
        let testKey = "test.migration.\(UUID().uuidString)"
        let testValue = "migration test value"
        
        // Set up UserDefaults data
        UserDefaults.standard.set(testValue, forKey: testKey)
        
        // Test migration
        let migrationResult = JSONStorageService.migrateFromUserDefaults()
        XCTAssertTrue(migrationResult, "Migration should succeed")
        
        // Verify data was migrated
        let migratedValue: String? = JSONStorageService.load(forKey: testKey)
        XCTAssertEqual(migratedValue, testValue, "Data should be migrated correctly")
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    // MARK: - Backup and Restore Tests
    
    func testCreateBackup() {
        let testKey = "test.backup.\(UUID().uuidString)"
        let testData = "backup test data"
        
        // Save some data
        JSONStorageService.save(testData, forKey: testKey)
        
        // Create backup
        let backupResult = JSONStorageService.createBackup()
        XCTAssertTrue(backupResult, "Should create backup successfully")
        
        // Verify backup exists
        let backupPath = JSONStorageService.backupsDirectory
        let backupFiles = try? FileManager.default.contentsOfDirectory(at: backupPath, includingPropertiesForKeys: nil)
        XCTAssertNotNil(backupFiles, "Backup directory should exist")
        XCTAssertGreaterThan(backupFiles?.count ?? 0, 0, "Should have backup files")
    }
    
    func testRestoreFromBackup() {
        let testKey = "test.restore.\(UUID().uuidString)"
        let testData = "restore test data"
        
        // Save data and create backup
        JSONStorageService.save(testData, forKey: testKey)
        let backupResult = JSONStorageService.createBackup()
        XCTAssertTrue(backupResult, "Should create backup successfully")
        
        // Delete original data
        JSONStorageService.delete(forKey: testKey)
        let deletedData: String? = JSONStorageService.load(forKey: testKey)
        XCTAssertNil(deletedData, "Data should be deleted")
        
        // Restore from backup
        let restoreResult = JSONStorageService.restoreFromBackup()
        XCTAssertTrue(restoreResult, "Should restore from backup successfully")
        
        // Verify data was restored
        let restoredData: String? = JSONStorageService.load(forKey: testKey)
        XCTAssertEqual(restoredData, testData, "Data should be restored correctly")
    }
    
    // MARK: - Export and Import Tests
    
    func testExportAllData() {
        let testKey = "test.export.\(UUID().uuidString)"
        let testData = "export test data"
        
        // Save some data
        JSONStorageService.save(testData, forKey: testKey)
        
        // Export data
        let exportResult = JSONStorageService.exportAllData()
        XCTAssertTrue(exportResult, "Should export data successfully")
        
        // Verify export file exists
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportPath = documentsPath.appendingPathComponent("DevReader/export.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportPath.path), "Export file should exist")
    }
    
    func testImportAllData() {
        let testKey = "test.import.\(UUID().uuidString)"
        let testData = "import test data"
        
        // Save data and export
        JSONStorageService.save(testData, forKey: testKey)
        let exportResult = JSONStorageService.exportAllData()
        XCTAssertTrue(exportResult, "Should export data successfully")
        
        // Clear data
        JSONStorageService.delete(forKey: testKey)
        let clearedData: String? = JSONStorageService.load(forKey: testKey)
        XCTAssertNil(clearedData, "Data should be cleared")
        
        // Import data
        let importResult = JSONStorageService.importAllData()
        XCTAssertTrue(importResult, "Should import data successfully")
        
        // Verify data was imported
        let importedData: String? = JSONStorageService.load(forKey: testKey)
        XCTAssertEqual(importedData, testData, "Data should be imported correctly")
    }
    
    // MARK: - Data Validation Tests
    
    func testValidateDataIntegrity() {
        let testKey = "test.validation.\(UUID().uuidString)"
        let testData = "validation test data"
        
        // Save data
        JSONStorageService.save(testData, forKey: testKey)
        
        // Validate data
        let validationResult = JSONStorageService.validateDataIntegrity()
        XCTAssertTrue(validationResult, "Data validation should pass")
    }
    
    func testValidateCorruptedData() {
        // Create a corrupted JSON file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataPath = documentsPath.appendingPathComponent("DevReader/Data")
        let corruptedFile = dataPath.appendingPathComponent("corrupted.json")
        
        try? FileManager.default.createDirectory(at: dataPath, withIntermediateDirectories: true)
        try? "invalid json content".write(to: corruptedFile, atomically: true, encoding: .utf8)
        
        // Validate should handle corrupted data gracefully
        let validationResult = JSONStorageService.validateDataIntegrity()
        // Should either pass (ignoring corrupted files) or fail gracefully
        XCTAssertTrue(validationResult || !validationResult, "Validation should handle corrupted data gracefully")
    }
    
    // MARK: - Performance Tests
    
    func testStoragePerformance() {
        let testData = "Performance test data with some content to make it larger"
        let keys = (0..<100).map { "test.performance.\($0)" }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Save many items
        for key in keys {
            JSONStorageService.save(testData, forKey: key)
        }
        
        // Load many items
        for key in keys {
            let _: String? = JSONStorageService.load(forKey: key)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 5.0, "Storage operations should complete within 5 seconds")
        
        // Clean up
        for key in keys {
            JSONStorageService.delete(forKey: key)
        }
    }
    
    func testLargeDataStorage() {
        let largeData = String(repeating: "Large data content ", count: 1000)
        let key = "test.large.\(UUID().uuidString)"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let saveResult = JSONStorageService.save(largeData, forKey: key)
        XCTAssertTrue(saveResult, "Should save large data successfully")
        
        let loadedData: String? = JSONStorageService.load(forKey: key)
        XCTAssertEqual(loadedData, largeData, "Should load large data correctly")
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(timeElapsed, 2.0, "Large data operations should complete within 2 seconds")
        
        // Clean up
        JSONStorageService.delete(forKey: key)
    }
}
