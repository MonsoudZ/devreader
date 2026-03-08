import XCTest
@testable import DevReader

@MainActor
final class NotesStoreTests: XCTestCase {
    var store: NotesStore!
    var mockPersistence: MockNotesPersistenceService!
    let testURL = URL(fileURLWithPath: "/tmp/test_notes.pdf")

    override func setUp() async throws {
        mockPersistence = MockNotesPersistenceService()
        store = NotesStore(persistenceService: mockPersistence)
        store.setCurrentPDF(testURL)
        await store.loadingTask?.value
    }

    override func tearDown() {
        store = nil
        mockPersistence = nil
    }

    // MARK: - Basic CRUD

    func testAddNote() {
        let note = NoteItem(text: "Hello", pageIndex: 1, chapter: "Ch1")
        store.add(note)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.text, "Hello")
    }

    func testRemoveNote() {
        let note = NoteItem(text: "To remove", pageIndex: 1, chapter: "Ch1")
        store.add(note)
        XCTAssertEqual(store.items.count, 1)

        store.remove(note)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testUpdateText() {
        let note = NoteItem(text: "Original", pageIndex: 1, chapter: "Ch1")
        store.add(note)

        store.updateText("Updated", for: note)

        XCTAssertEqual(store.items.first?.text, "Updated")
    }

    func testUpdateNoteTitle() {
        let note = NoteItem(text: "Body", pageIndex: 1, chapter: "Ch1")
        store.add(note)

        store.updateNote(title: "New Title", text: "New Body", for: note)

        XCTAssertEqual(store.items.first?.title, "New Title")
        XCTAssertEqual(store.items.first?.text, "New Body")
    }

    // MARK: - Grouping

    func testGroupedByChapter() {
        store.add(NoteItem(text: "A", pageIndex: 1, chapter: "Ch1"))
        store.add(NoteItem(text: "B", pageIndex: 2, chapter: "Ch2"))
        store.add(NoteItem(text: "C", pageIndex: 3, chapter: "Ch1"))

        let grouped = store.groupedByChapter()

        XCTAssertEqual(grouped.count, 2)
        let ch1 = grouped.first(where: { $0.key == "Ch1" })
        XCTAssertEqual(ch1?.value.count, 2)
    }

    // MARK: - Page Notes

    func testPageNotes() {
        store.setNote("Page 1 note", for: 1)
        store.setNote("Page 5 note", for: 5)

        XCTAssertEqual(store.note(for: 1), "Page 1 note")
        XCTAssertEqual(store.note(for: 5), "Page 5 note")
        XCTAssertEqual(store.note(for: 99), "")
    }

    // MARK: - Tags

    func testAddAndRemoveTag() {
        let note = NoteItem(text: "Tagged", pageIndex: 1, chapter: "Ch1")
        store.add(note)

        store.addTag("important", to: note)
        XCTAssertTrue(store.items.first?.tags.contains("important") ?? false)
        XCTAssertTrue(store.availableTags.contains("important"))

        guard let firstItem = store.items.first else {
            XCTFail("Store should have at least one item")
            return
        }
        store.removeTag("important", from: firstItem)
        XCTAssertFalse(store.items.first?.tags.contains("important") ?? true)
    }

    func testNotesWithTag() {
        let note1 = NoteItem(text: "A", pageIndex: 1, chapter: "Ch1")
        let note2 = NoteItem(text: "B", pageIndex: 2, chapter: "Ch1")
        store.add(note1)
        store.add(note2)

        store.addTag("review", to: store.items[0])

        let tagged = store.notesWithTag("review")
        XCTAssertEqual(tagged.count, 1)
        XCTAssertEqual(tagged.first?.text, "B") // note2 is at index 0 (items.insert at 0)
    }

    // MARK: - PDF Switching

    func testSwitchPDF() async {
        let url2 = URL(fileURLWithPath: "/tmp/other.pdf")

        store.add(NoteItem(text: "PDF1 note", pageIndex: 1, chapter: "Ch1"))
        XCTAssertEqual(store.items.count, 1)

        // Switch to another PDF
        store.setCurrentPDF(url2)
        await store.loadingTask?.value
        XCTAssertTrue(store.items.isEmpty, "New PDF should start with no notes")

        // Switch back
        store.setCurrentPDF(testURL)
        await store.loadingTask?.value
        XCTAssertEqual(store.items.count, 1, "Notes should be reloaded from mock")
    }

    func testSetCurrentPDFNil() {
        store.add(NoteItem(text: "note", pageIndex: 1, chapter: "Ch1"))

        store.setCurrentPDF(nil)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.pageNotes.isEmpty)
    }

    // MARK: - Basic Functionality

    func testSetCurrentPDFSeparatesNotes() async {
        let urlA = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("a_\(UUID().uuidString).pdf")

        store.setCurrentPDF(urlA)
        await store.loadingTask?.value
        store.setNote("hello", for: 1)
        XCTAssertEqual(store.note(for: 1), "hello")

        store.add(NoteItem(text: "test note", pageIndex: 1, chapter: ""))
        XCTAssertEqual(store.items.count, 1)
    }
}
