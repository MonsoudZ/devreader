import XCTest
@testable import DevReader

@MainActor
final class SketchStoreTests: XCTestCase {
    var store: SketchStore!
    var mockPersistence: MockSketchPersistenceService!
    let testPDFURL = URL(fileURLWithPath: "/tmp/test.pdf")

    override func setUp() {
        mockPersistence = MockSketchPersistenceService()
        store = SketchStore(persistenceService: mockPersistence)
    }

    override func tearDown() {
        store = nil
        mockPersistence = nil
    }

    // MARK: - Sketch Tests

    func testCreateSketch() {
        store.createSketch(for: testPDFURL, pageIndex: 0)

        XCTAssertEqual(store.sketches.count, 1)
        XCTAssertEqual(store.sketches.first?.pdfURL, testPDFURL)
        XCTAssertEqual(store.sketches.first?.pageIndex, 0)
        XCTAssertNotNil(store.currentSketch)
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
    }

    func testCreateSketchWithStrokes() {
        let canvasData = Data([0x01, 0x02, 0x03])
        let strokesData = Data([0x04, 0x05])
        store.createSketch(for: testPDFURL, pageIndex: 1, canvasData: canvasData, strokesData: strokesData)

        XCTAssertEqual(store.sketches.count, 1)
        XCTAssertEqual(store.sketches.first?.canvasData, canvasData)
        XCTAssertEqual(store.sketches.first?.strokesData, strokesData)
    }

    func testUpdateCurrentSketch() {
        store.createSketch(for: testPDFURL, pageIndex: 0)
        let newData = Data([0xFF, 0xFE])

        store.updateCurrentSketch(newData)

        XCTAssertEqual(store.currentSketch?.canvasData, newData)
        XCTAssertEqual(store.sketches.first?.canvasData, newData)
    }

    func testDeleteSketch() {
        store.createSketch(for: testPDFURL, pageIndex: 0)
        let sketch = store.sketches.first!

        store.deleteSketch(sketch)

        XCTAssertTrue(store.sketches.isEmpty)
        XCTAssertNil(store.currentSketch)
    }

    func testGetSketchesForPDF() {
        let otherURL = URL(fileURLWithPath: "/tmp/other.pdf")
        store.createSketch(for: testPDFURL, pageIndex: 0)
        store.createSketch(for: testPDFURL, pageIndex: 1)
        store.createSketch(for: otherURL, pageIndex: 0)

        let sketches = store.getSketches(for: testPDFURL)

        XCTAssertEqual(sketches.count, 2)
    }

    func testGetSketchesForPDFAndPage() {
        store.createSketch(for: testPDFURL, pageIndex: 0)
        store.createSketch(for: testPDFURL, pageIndex: 1)
        store.createSketch(for: testPDFURL, pageIndex: 0)

        let sketches = store.getSketches(for: testPDFURL, pageIndex: 0)

        XCTAssertEqual(sketches.count, 2)
    }

    func testClearAllData() {
        store.createSketch(for: testPDFURL, pageIndex: 0)
        store.createSketch(for: testPDFURL, pageIndex: 1)

        store.clearAllData()

        XCTAssertTrue(store.sketches.isEmpty)
        XCTAssertNil(store.currentSketch)
    }

    func testLoadOnInit() {
        let freshMock = MockSketchPersistenceService()
        freshMock.sketches = [
            SketchItem(
                pdfURL: testPDFURL,
                pageIndex: 0,
                title: "Preloaded",
                createdDate: Date(),
                lastModified: Date(),
                canvasData: Data()
            )
        ]
        let newStore = SketchStore(persistenceService: freshMock)
        // Keep newStore alive until XCTest teardown phase to avoid @MainActor deinit crash
        addTeardownBlock { [newStore] in _ = newStore }

        XCTAssertEqual(newStore.sketches.count, 1)
        XCTAssertEqual(newStore.sketches.first?.title, "Preloaded")
    }
}
