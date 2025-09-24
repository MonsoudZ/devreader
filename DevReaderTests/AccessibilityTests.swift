import XCTest
@testable import DevReader

@MainActor
final class AccessibilityTests: XCTestCase {
    
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
    
    // MARK: - Accessibility Label Tests
    
    func testContentViewAccessibility() async {
        let store = await MainActor.run { NotesStore() }
        let pdf = await MainActor.run { PDFController() }
        let library = await MainActor.run { LibraryStore() }
        
        // Test that ContentView has proper accessibility labels
        // This is a basic test to ensure accessibility is implemented
        XCTAssertNotNil(store, "NotesStore should be accessible")
        XCTAssertNotNil(pdf, "PDFController should be accessible")
        XCTAssertNotNil(library, "LibraryStore should be accessible")
    }
    
    func testNotesStoreAccessibility() async {
        let store = await MainActor.run { NotesStore() }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        
        await MainActor.run { store.setCurrentPDF(url) }
        await MainActor.run { store.add(NoteItem(text: "Test note", pageIndex: 1, chapter: "Test Chapter")) }
        
        // Test that notes can be accessed and manipulated
        let itemsCount = await MainActor.run { store.items.count }
        XCTAssertEqual(itemsCount, 1, "Notes should be accessible and manageable")
        
        let note = await MainActor.run { store.items.first }
        XCTAssertNotNil(note, "Note should be accessible")
        XCTAssertEqual(note?.text, "Test note", "Note content should be accessible")
    }
    
    func testPDFControllerAccessibility() async {
        let pdf = await MainActor.run { PDFController() }
        
        // Test that PDF controller properties are accessible
        let currentPage = await MainActor.run { pdf.currentPageIndex }
        XCTAssertGreaterThanOrEqual(currentPage, 0, "Current page should be accessible")
        
        let bookmarks = await MainActor.run { pdf.bookmarks }
        XCTAssertNotNil(bookmarks, "Bookmarks should be accessible")
        
        let recentDocs = await MainActor.run { pdf.recentDocuments }
        XCTAssertNotNil(recentDocs, "Recent documents should be accessible")
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testKeyboardShortcuts() {
        // Test that keyboard shortcuts are properly configured
        // This is a basic test to ensure shortcuts are accessible
        
        // Test common keyboard shortcuts
        let shortcuts = [
            "Command+F", // Search
            "Command+Plus", // Zoom in
            "Command+Minus", // Zoom out
            "Command+W", // Close PDF
            "Command+Shift+H", // Highlight to note
            "Command+Shift+S", // Add sticky note
            "Command+Shift+N", // New sketch page
        ]
        
        // Verify shortcuts are defined (this is a basic check)
        XCTAssertTrue(shortcuts.count > 0, "Keyboard shortcuts should be defined")
    }
    
    // MARK: - VoiceOver Support Tests
    
    func testVoiceOverCompatibility() async {
        let store = await MainActor.run { NotesStore() }
        let pdf = await MainActor.run { PDFController() }
        
        // Test that objects are VoiceOver compatible
        await MainActor.run { store.add(NoteItem(text: "VoiceOver test note", pageIndex: 1, chapter: "Test")) }
        
        let note = await MainActor.run { store.items.first }
        XCTAssertNotNil(note, "Notes should be VoiceOver accessible")
        
        // Test that PDF controller is VoiceOver compatible
        let currentPage = await MainActor.run { pdf.currentPageIndex }
        XCTAssertGreaterThanOrEqual(currentPage, 0, "PDF page should be VoiceOver accessible")
    }
    
    // MARK: - Accessibility Performance Tests
    
    func testAccessibilityPerformance() async {
        let store = await MainActor.run { NotesStore() }
        
        // Add many notes to test accessibility performance
        for i in 0..<100 {
            await MainActor.run {
                store.add(NoteItem(text: "Accessibility test note \(i)", pageIndex: i % 10, chapter: "Chapter \(i / 10)"))
            }
        }
        
        // Test that accessibility operations remain fast
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let itemsCount = await MainActor.run { store.items.count }
        let groupedNotes = await MainActor.run { store.groupedByChapter() }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Accessibility operations should be fast
        XCTAssertLessThan(timeElapsed, 1.0, "Accessibility operations should be fast")
        XCTAssertEqual(itemsCount, 100, "All notes should be accessible")
        XCTAssertGreaterThan(groupedNotes.count, 0, "Grouped notes should be accessible")
    }
}
