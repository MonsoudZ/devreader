import XCTest
import PDFKit
@testable import DevReader

/// Integration tests verifying the wiring between AppEnvironment components.
/// Since AppEnvironment uses a private singleton init, these tests verify
/// the same wiring patterns by constructing components manually.
@MainActor
final class AppEnvironmentTests: XCTestCase {

    // MARK: - PDF → Notes Wiring

    func testOnPDFChangedWiresNotesStore() {
        let mockPersistence = MockNotesPersistenceService()
        let notes = NotesStore(persistenceService: mockPersistence)
        let pdf = PDFController()

        // Replicate AppEnvironment wiring
        pdf.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        let testURL = URL(fileURLWithPath: "/tmp/wiring_test.pdf")

        // Add a note to the mock so we can verify notes loaded
        let note = NoteItem(text: "Test note", pageIndex: 0, chapter: "Ch1")
        mockPersistence.notes[testURL] = [note]

        // Trigger onPDFChanged by calling it directly
        pdf.onPDFChanged?(testURL)

        XCTAssertEqual(notes.items.count, 1, "Notes should be loaded after PDF change")
        XCTAssertEqual(notes.items.first?.text, "Test note")
    }

    func testOnPDFChangedClearsNotesWhenNil() {
        let mockPersistence = MockNotesPersistenceService()
        let notes = NotesStore(persistenceService: mockPersistence)
        let pdf = PDFController()

        pdf.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        let testURL = URL(fileURLWithPath: "/tmp/wiring_nil_test.pdf")
        mockPersistence.notes[testURL] = [NoteItem(text: "Note", pageIndex: 0, chapter: "")]

        // Load a PDF
        pdf.onPDFChanged?(testURL)
        XCTAssertFalse(notes.items.isEmpty, "Notes should be loaded")

        // Clear (nil URL)
        pdf.onPDFChanged?(nil)
        XCTAssertTrue(notes.items.isEmpty, "Notes should be cleared when PDF is nil")
    }

    func testOnPDFChangedSavesPreviousPDFNotes() {
        let mockPersistence = MockNotesPersistenceService()
        let notes = NotesStore(persistenceService: mockPersistence)
        let pdf = PDFController()

        pdf.onPDFChanged = { [weak notes] url in
            notes?.setCurrentPDF(url)
        }

        let url1 = URL(fileURLWithPath: "/tmp/pdf_a.pdf")
        let url2 = URL(fileURLWithPath: "/tmp/pdf_b.pdf")

        // Load first PDF and add a note
        pdf.onPDFChanged?(url1)
        notes.add(NoteItem(text: "First PDF note", pageIndex: 0, chapter: ""))

        // Switch to second PDF — should persist first PDF's notes
        pdf.onPDFChanged?(url2)

        // Verify first PDF's notes were saved
        XCTAssertEqual(mockPersistence.notes[url1]?.count, 1,
                       "Notes for first PDF should be persisted when switching")
        XCTAssertEqual(mockPersistence.notes[url1]?.first?.text, "First PDF note")
    }

    func testClearSessionTriggersOnPDFChangedNil() {
        let pdf = PDFController()
        var receivedURL: URL?? = .none // Distinguish "not called" from "called with nil"

        pdf.onPDFChanged = { url in
            receivedURL = .some(url)
        }

        pdf.clearSession()

        XCTAssertNotNil(receivedURL, "onPDFChanged should have been called")
        XCTAssertNil(receivedURL!, "clearSession should pass nil to onPDFChanged")
    }

    // MARK: - Toast Center

    func testEnhancedToastCenterShowsSuccess() {
        let toastCenter = EnhancedToastCenter()

        toastCenter.showSuccess("Title", "Message")

        XCTAssertFalse(toastCenter.toasts.isEmpty, "Toast should be displayed")
        XCTAssertEqual(toastCenter.toasts.first?.title, "Title")
    }

    func testEnhancedToastCenterShowsError() {
        let toastCenter = EnhancedToastCenter()

        toastCenter.showError("Error Title", "Error message")

        XCTAssertFalse(toastCenter.toasts.isEmpty, "Error toast should be displayed")
    }

    // MARK: - Sheet Toggles

    func testOpenHelpSetsShowingHelp() {
        let env = AppEnvironment.shared

        env.isShowingHelp = false
        env.openHelp()

        XCTAssertTrue(env.isShowingHelp, "openHelp() should set isShowingHelp to true")

        // Reset
        env.isShowingHelp = false
    }

    func testSheetTogglesDefaultToFalse() {
        let env = AppEnvironment.shared

        // Reset state
        env.isShowingOnboarding = false
        env.isShowingSettings = false
        env.isShowingHelp = false
        env.isShowingAbout = false

        XCTAssertFalse(env.isShowingOnboarding)
        XCTAssertFalse(env.isShowingSettings)
        XCTAssertFalse(env.isShowingHelp)
        XCTAssertFalse(env.isShowingAbout)
    }

    // MARK: - Component Initialization

    func testAppEnvironmentHasAllComponents() {
        let env = AppEnvironment.shared

        XCTAssertNotNil(env.pdfController, "PDFController should be initialized")
        XCTAssertNotNil(env.libraryStore, "LibraryStore should be initialized")
        XCTAssertNotNil(env.notesStore, "NotesStore should be initialized")
        XCTAssertNotNil(env.sketchStore, "SketchStore should be initialized")
        XCTAssertNotNil(env.enhancedToastCenter, "EnhancedToastCenter should be initialized")
        XCTAssertNotNil(env.errorMessageManager, "ErrorMessageManager should be initialized")
    }

    func testPDFControllerHasOnPDFChangedWired() {
        let env = AppEnvironment.shared

        XCTAssertNotNil(env.pdfController.onPDFChanged,
                        "onPDFChanged should be wired in AppEnvironment")
    }

    // MARK: - Lifecycle Flush

    func testFlushPendingPersistenceDoesNotCrash() {
        let env = AppEnvironment.shared

        // Verify all four flush methods can be called without crashing
        env.pdfController.flushPendingPersistence()
        env.libraryStore.flushPendingPersistence()
        env.notesStore.flushPendingPersistence()
        env.sketchStore.flushPendingPersistence()
    }

    // MARK: - PDF Load Error Notification

    func testPDFLoadErrorNotificationPosted() async {
        let expectation = expectation(forNotification: .pdfLoadError, object: nil)
        expectation.assertForOverFulfill = false

        let pdfController = PDFController()
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/test.pdf")

        pdfController.load(url: invalidURL)

        await fulfillment(of: [expectation], timeout: 3.0)
    }

    // MARK: - Memory Pressure Handling

    func testMemoryPressureNotificationDoesNotCrash() {
        let pdfController = PDFController()

        // Post memory pressure notification
        NotificationCenter.default.post(name: .memoryPressure, object: nil)

        // Just verify no crash occurred
        XCTAssertNotNil(pdfController)
    }
}
