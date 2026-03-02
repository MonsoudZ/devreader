import XCTest
@testable import DevReader

@MainActor
final class CodeStoreTests: XCTestCase {
    var store: CodeStore!
    var mockPersistence: MockCodePersistenceService!

    override func setUp() {
        mockPersistence = MockCodePersistenceService()
        store = CodeStore(persistenceService: mockPersistence)
    }

    override func tearDown() {
        store = nil
        mockPersistence = nil
    }

    // MARK: - Snippet Tests

    func testCreateSnippet() {
        store.createSnippet(title: "Hello", content: "print(\"hello\")", language: "swift")

        XCTAssertEqual(store.codeSnippets.count, 1)
        XCTAssertEqual(store.codeSnippets.first?.title, "Hello")
        XCTAssertEqual(store.codeSnippets.first?.language, "swift")
        XCTAssertNotNil(store.currentSnippet)
        XCTAssertEqual(store.currentSnippet?.id, store.codeSnippets.first?.id)
    }

    func testUpdateCurrentSnippet() {
        store.createSnippet(title: "Test", content: "original", language: "swift")

        store.updateCurrentSnippet("updated content")

        XCTAssertEqual(store.currentSnippet?.content, "updated content")
        XCTAssertEqual(store.codeSnippets.first?.content, "updated content")
    }

    func testDeleteCurrentSnippet() {
        store.createSnippet(title: "ToDelete", content: "delete me", language: "swift")
        let snippet = store.codeSnippets.first!

        store.deleteSnippet(snippet)

        XCTAssertTrue(store.codeSnippets.isEmpty)
        XCTAssertNil(store.currentSnippet)
    }

    func testDeleteNonCurrentSnippet() {
        store.createSnippet(title: "First", content: "1", language: "swift")
        store.createSnippet(title: "Second", content: "2", language: "swift")

        let first = store.codeSnippets.first!
        store.deleteSnippet(first)

        XCTAssertEqual(store.codeSnippets.count, 1)
        XCTAssertEqual(store.codeSnippets.first?.title, "Second")
        // currentSnippet should still be set (to "Second")
        XCTAssertNotNil(store.currentSnippet)
    }

    func testExportSnippet() {
        store.createSnippet(title: "Export", content: "export content", language: "swift")
        let snippet = store.codeSnippets.first!

        let exportURL = store.exportSnippet(snippet)

        XCTAssertNotNil(exportURL)
        if let url = exportURL {
            let content = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(content, "export content")
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testLoadOnInit() {
        let freshMock = MockCodePersistenceService()
        freshMock.snippets = [
            CodeSnippet(title: "Pre", content: "content", language: "python", createdDate: Date(), lastModified: Date())
        ]
        let newStore = CodeStore(persistenceService: freshMock)
        // Keep newStore alive until XCTest teardown phase to avoid @MainActor deinit crash
        addTeardownBlock { [newStore] in _ = newStore }

        XCTAssertEqual(newStore.codeSnippets.count, 1)
        XCTAssertEqual(newStore.codeSnippets.first?.title, "Pre")
    }

    func testClearAllData() {
        store.createSnippet(title: "Test", content: "content", language: "swift")

        store.clearAllData()

        XCTAssertTrue(store.codeSnippets.isEmpty)
        XCTAssertNil(store.currentSnippet)
    }
}
