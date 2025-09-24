import XCTest
@testable import DevReader

@MainActor
final class PerformanceTests: XCTestCase {
    
    override func tearDownWithError() throws {
        // Clear all UserDefaults to prevent test interference
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("DevReader.") {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - Large PDF Performance Tests
    
    func testLargePDFLoadingPerformance() async {
        // This test simulates loading a large PDF (1000+ pages)
        // In a real scenario, you would use an actual large PDF file
        
        let store = await MainActor.run { NotesStore() }
        let pdf = await MainActor.run { PDFController() }
        
        // Simulate large PDF with many pages
        let largePDFURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("large_test.pdf")
        
        // Measure loading time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await MainActor.run { store.setCurrentPDF(largePDFURL) }
        
        // Simulate adding many notes (performance test)
        for i in 0..<1000 {
            await MainActor.run { 
                store.add(NoteItem(text: "Test note \(i)", pageIndex: i % 100, chapter: "Chapter \(i / 100)"))
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Performance assertion: should complete within reasonable time
        XCTAssertLessThan(timeElapsed, 5.0, "Large PDF operations should complete within 5 seconds")
        
        // Verify data integrity
        let itemsCount = await MainActor.run { store.items.count }
        XCTAssertEqual(itemsCount, 1000, "All notes should be added successfully")
    }
    
    func testSearchPerformance() async {
        let store = await MainActor.run { NotesStore() }
        let pdf = await MainActor.run { PDFController() }
        
        // Add many notes with searchable content
        for i in 0..<500 {
            await MainActor.run {
                store.add(NoteItem(text: "Searchable content \(i) with keywords", pageIndex: i % 50, chapter: "Chapter \(i / 50)"))
            }
        }
        
        // Measure search performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate search operations
        for _ in 0..<10 {
            await MainActor.run { pdf.performSearch("keywords") }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Search should be fast even with many notes
        XCTAssertLessThan(timeElapsed, 2.0, "Search operations should complete within 2 seconds")
    }
    
    func testMemoryUsage() async {
        let store = await MainActor.run { NotesStore() }
        
        // Add many notes to test memory usage
        for i in 0..<2000 {
            await MainActor.run {
                store.add(NoteItem(text: "Memory test note \(i) with some content to test memory usage", pageIndex: i % 100, chapter: "Chapter \(i / 100)"))
            }
        }
        
        // Verify we can still perform operations without memory issues
        let itemsCount = await MainActor.run { store.items.count }
        XCTAssertEqual(itemsCount, 2000, "Should handle 2000 notes without memory issues")
        
        // Test that we can still search efficiently
        let startTime = CFAbsoluteTimeGetCurrent()
        let filteredNotes = await MainActor.run { store.items.filter { $0.text.contains("Memory test") } }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 1.0, "Filtering should be fast even with many notes")
        XCTAssertEqual(filteredNotes.count, 2000, "All notes should be found in search")
    }
    
    // MARK: - UI Performance Tests
    
    func testUIResponsiveness() async {
        let store = await MainActor.run { NotesStore() }
        
        // Add many notes to test UI responsiveness
        for i in 0..<1000 {
            await MainActor.run {
                store.add(NoteItem(text: "UI test note \(i)", pageIndex: i % 50, chapter: "Chapter \(i / 50)"))
            }
        }
        
        // Test that UI operations remain responsive
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate UI operations
        for _ in 0..<100 {
            let _ = await MainActor.run { store.items.count }
            let _ = await MainActor.run { store.groupedByChapter() }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // UI operations should remain fast
        XCTAssertLessThan(timeElapsed, 3.0, "UI operations should remain responsive")
    }
    
    // MARK: - Persistence Performance Tests
    
    func testPersistencePerformance() async {
        let store = await MainActor.run { NotesStore() }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("persistence_test.pdf")
        
        await MainActor.run { store.setCurrentPDF(url) }
        
        // Add many notes to test persistence performance
        for i in 0..<1000 {
            await MainActor.run {
                store.add(NoteItem(text: "Persistence test note \(i)", pageIndex: i % 100, chapter: "Chapter \(i / 100)"))
            }
        }
        
        // Measure persistence time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Force persistence
        await MainActor.run { store.setCurrentPDF(nil) }
        await MainActor.run { store.setCurrentPDF(url) }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Persistence should be reasonably fast
        XCTAssertLessThan(timeElapsed, 2.0, "Persistence operations should complete within 2 seconds")
        
        // Verify data was persisted correctly
        let itemsCount = await MainActor.run { store.items.count }
        XCTAssertEqual(itemsCount, 1000, "All notes should be persisted correctly")
    }
}
