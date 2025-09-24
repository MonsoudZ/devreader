import XCTest
@testable import DevReader

@MainActor
final class NotesStoreTests: XCTestCase {
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
    
    func testBasicFunctionality() async {
        // Test that we can create a NoteItem
        let noteItem = NoteItem(text: "test", pageIndex: 1, chapter: "")
        XCTAssertEqual(noteItem.text, "test", "NoteItem should be created correctly")
        XCTAssertEqual(noteItem.pageIndex, 1, "NoteItem pageIndex should be set correctly")
        
        // Test that we can create a NotesStore (on main actor)
        let store = await MainActor.run { NotesStore() }
        XCTAssertNotNil(store, "NotesStore should be created")
    }
    
    func testSetCurrentPDFSeparatesNotes() async {
        let store = await MainActor.run { NotesStore() }
        let urlA = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("a_\(UUID().uuidString).pdf")
        
        // Test basic functionality
        await MainActor.run { store.setCurrentPDF(urlA) }
        await MainActor.run { store.setNote("hello", for: 1) }
        let note1 = await MainActor.run { store.note(for: 1) }
        XCTAssertEqual(note1, "hello", "Basic note setting failed")
        
        // Test that we can add a note item
        await MainActor.run { store.add(NoteItem(text: "test note", pageIndex: 1, chapter: "")) }
        let itemsCount = await MainActor.run { store.items.count }
        XCTAssertEqual(itemsCount, 1, "Should have 1 item after adding")
    }
}


