import XCTest
@testable import DevReader

@MainActor
final class LibraryStoreTests: XCTestCase {
	var store: LibraryStore!

	override func setUp() {
		// Use fresh instances to isolate tests
		store = LibraryStore(
			backgroundService: LibraryPersistenceService(),
			loadingStateManager: LoadingStateManager()
		)
		// Clear any restored items
		store.items.removeAll()
		addTeardownBlock { [store] in _ = store }
	}

	override func tearDown() {
		store = nil
	}

	/// Polls until the store's item count reaches the expected value (or timeout).
	private func waitForItems(count expected: Int, timeout: TimeInterval = 2.0) async {
		await waitUntil(timeout: timeout) { [store] in store!.items.count >= expected }
	}

	// MARK: - Add / Remove

	func testAddSinglePDF() async {
		let url = makeTempPDFStub(named: "test1")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		await waitForItems(count: 1)

		XCTAssertEqual(store.items.count, 1)
		XCTAssertEqual(store.items.first?.url, url)
	}

	func testAddMultiplePDFs() async {
		let url1 = makeTempPDFStub(named: "a")
		let url2 = makeTempPDFStub(named: "b")
		defer {
			try? FileManager.default.removeItem(at: url1)
			try? FileManager.default.removeItem(at: url2)
		}

		store.add(urls: [url1, url2])
		await waitForItems(count: 2)

		XCTAssertEqual(store.items.count, 2)
	}

	func testAddRejectsNonPDFFiles() async {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("test_\(UUID().uuidString).txt")
		try? "text".write(to: url, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		// Wait briefly — nothing should be added
		// Yield to let any pending async work settle
		try? await Task.sleep(nanoseconds: 300_000_000)

		XCTAssertEqual(store.items.count, 0, "Non-PDF files should be filtered out")
	}

	func testRemoveItem() async {
		let url = makeTempPDFStub(named: "toremove")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		await waitForItems(count: 1)
		XCTAssertEqual(store.items.count, 1)

		let item = store.items.first!
		store.remove(item)
		XCTAssertTrue(store.items.isEmpty)
	}

	func testRemoveByIDs() async {
		let url1 = makeTempPDFStub(named: "r1")
		let url2 = makeTempPDFStub(named: "r2")
		defer {
			try? FileManager.default.removeItem(at: url1)
			try? FileManager.default.removeItem(at: url2)
		}

		store.add(urls: [url1, url2])
		await waitForItems(count: 2)
		XCTAssertEqual(store.items.count, 2)

		let ids = Set(store.items.map { $0.id })
		store.remove(ids: ids)
		XCTAssertTrue(store.items.isEmpty)
	}

	// MARK: - Duplicate Detection

	func testAddDuplicateURLIsRejected() async {
		let url = makeTempPDFStub(named: "dup")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		await waitForItems(count: 1)
		XCTAssertEqual(store.items.count, 1)

		// Add the same URL again
		store.add(urls: [url])
		// Wait briefly — count should stay at 1
		// Yield to let any pending async work settle
		try? await Task.sleep(nanoseconds: 300_000_000)
		XCTAssertEqual(store.items.count, 1, "Duplicate URL should not be added")
	}

	// MARK: - Sort Order

	func testItemsSortedByDateDescending() async {
		let url1 = makeTempPDFStub(named: "first")
		let url2 = makeTempPDFStub(named: "second")
		defer {
			try? FileManager.default.removeItem(at: url1)
			try? FileManager.default.removeItem(at: url2)
		}

		store.add(urls: [url1])
		await waitForItems(count: 1)
		store.add(urls: [url2])
		await waitForItems(count: 2)

		XCTAssertEqual(store.items.count, 2)
		// Most recently added should be first
		XCTAssertEqual(store.items.first?.url, url2)
	}

	// MARK: - Persistence (debounced)

	func testFlushPendingPersistence() async {
		let url = makeTempPDFStub(named: "persist")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		await waitForItems(count: 1)
		XCTAssertEqual(store.items.count, 1)

		// Flush should not crash
		store.flushPendingPersistence()
	}
}
