import XCTest
@testable import DevReader

// MARK: - Mock

@MainActor
final class MockFormDataPersistenceService: FormDataPersistenceProtocol {
    private var storage: [URL: [FormFieldEntry]] = [:]
    var saveCallCount = 0
    var clearCallCount = 0
    var shouldThrowOnSave = false

    func saveFormData(_ entries: [FormFieldEntry], for url: URL) throws {
        if shouldThrowOnSave {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        storage[url] = entries
        saveCallCount += 1
    }

    func loadFormData(for url: URL) -> [FormFieldEntry] {
        return storage[url] ?? []
    }

    func clearFormData(for url: URL) {
        storage.removeValue(forKey: url)
        clearCallCount += 1
    }
}

// MARK: - Tests

@MainActor
final class FormDataPersistenceTests: XCTestCase {
    var mockService: MockFormDataPersistenceService!
    let testURL = URL(fileURLWithPath: "/tmp/form-test.pdf")

    override func setUp() async throws {
        mockService = MockFormDataPersistenceService()
    }

    override func tearDown() async throws {
        mockService = nil
    }

    // MARK: - Save and Load

    func testSaveAndLoadFormData() throws {
        let entries = [
            FormFieldEntry(fieldName: "name", pageIndex: 0, value: "John Doe", fieldType: "text"),
            FormFieldEntry(fieldName: "email", pageIndex: 0, value: "john@example.com", fieldType: "text"),
        ]

        try mockService.saveFormData(entries, for: testURL)
        let loaded = mockService.loadFormData(for: testURL)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].fieldName, "name")
        XCTAssertEqual(loaded[0].value, "John Doe")
        XCTAssertEqual(loaded[1].fieldName, "email")
        XCTAssertEqual(loaded[1].value, "john@example.com")
        XCTAssertEqual(mockService.saveCallCount, 1)
    }

    func testSaveOverwritesPreviousData() throws {
        let original = [
            FormFieldEntry(fieldName: "name", pageIndex: 0, value: "Old Name", fieldType: "text"),
        ]
        try mockService.saveFormData(original, for: testURL)

        let updated = [
            FormFieldEntry(fieldName: "name", pageIndex: 0, value: "New Name", fieldType: "text"),
            FormFieldEntry(fieldName: "age", pageIndex: 1, value: "30", fieldType: "text"),
        ]
        try mockService.saveFormData(updated, for: testURL)

        let loaded = mockService.loadFormData(for: testURL)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].value, "New Name")
        XCTAssertEqual(mockService.saveCallCount, 2)
    }

    // MARK: - Clear

    func testClearFormData() throws {
        let entries = [
            FormFieldEntry(fieldName: "field1", pageIndex: 0, value: "val", fieldType: "text"),
        ]
        try mockService.saveFormData(entries, for: testURL)

        mockService.clearFormData(for: testURL)

        let loaded = mockService.loadFormData(for: testURL)
        XCTAssertTrue(loaded.isEmpty)
        XCTAssertEqual(mockService.clearCallCount, 1)
    }

    func testClearNonexistentURLIsNoOp() {
        let unknownURL = URL(fileURLWithPath: "/tmp/unknown.pdf")

        mockService.clearFormData(for: unknownURL)

        XCTAssertEqual(mockService.clearCallCount, 1)
        XCTAssertTrue(mockService.loadFormData(for: unknownURL).isEmpty)
    }

    // MARK: - Load Unknown PDF

    func testLoadReturnsEmptyForUnknownPDF() {
        let unknownURL = URL(fileURLWithPath: "/tmp/never-saved.pdf")

        let loaded = mockService.loadFormData(for: unknownURL)

        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Isolation Between PDFs

    func testDifferentPDFsHaveIndependentData() throws {
        let url1 = URL(fileURLWithPath: "/tmp/form1.pdf")
        let url2 = URL(fileURLWithPath: "/tmp/form2.pdf")

        let entries1 = [FormFieldEntry(fieldName: "a", pageIndex: 0, value: "1", fieldType: "text")]
        let entries2 = [FormFieldEntry(fieldName: "b", pageIndex: 0, value: "2", fieldType: "text")]

        try mockService.saveFormData(entries1, for: url1)
        try mockService.saveFormData(entries2, for: url2)

        let loaded1 = mockService.loadFormData(for: url1)
        let loaded2 = mockService.loadFormData(for: url2)

        XCTAssertEqual(loaded1.count, 1)
        XCTAssertEqual(loaded1[0].fieldName, "a")
        XCTAssertEqual(loaded2.count, 1)
        XCTAssertEqual(loaded2[0].fieldName, "b")
    }

    // MARK: - FormFieldEntry Model

    func testFormFieldEntryCodable() throws {
        let entry = FormFieldEntry(fieldName: "checkbox", pageIndex: 2, value: "true", fieldType: "checkbox")

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(FormFieldEntry.self, from: data)

        XCTAssertEqual(decoded.fieldName, "checkbox")
        XCTAssertEqual(decoded.pageIndex, 2)
        XCTAssertEqual(decoded.value, "true")
        XCTAssertEqual(decoded.fieldType, "checkbox")
    }

    // MARK: - Error Handling

    func testSaveThrowsError() {
        mockService.shouldThrowOnSave = true
        let entries = [FormFieldEntry(fieldName: "f", pageIndex: 0, value: "v", fieldType: "text")]

        XCTAssertThrowsError(try mockService.saveFormData(entries, for: testURL))
    }
}
