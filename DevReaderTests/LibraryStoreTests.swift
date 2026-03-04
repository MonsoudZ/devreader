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

	// MARK: - Add / Remove

	func testAddSinglePDF() async {
		let url = makeTempPDF(named: "test1.pdf")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		// Wait for async Task inside add()
		try? await Task.sleep(nanoseconds: 200_000_000)

		XCTAssertEqual(store.items.count, 1)
		XCTAssertEqual(store.items.first?.url, url)
	}

	func testAddMultiplePDFs() async {
		let url1 = makeTempPDF(named: "a.pdf")
		let url2 = makeTempPDF(named: "b.pdf")
		defer {
			try? FileManager.default.removeItem(at: url1)
			try? FileManager.default.removeItem(at: url2)
		}

		store.add(urls: [url1, url2])
		try? await Task.sleep(nanoseconds: 200_000_000)

		XCTAssertEqual(store.items.count, 2)
	}

	func testAddRejectsNonPDFFiles() async {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
		try? "text".write(to: url, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		try? await Task.sleep(nanoseconds: 200_000_000)

		XCTAssertEqual(store.items.count, 0, "Non-PDF files should be filtered out")
	}

	func testRemoveItem() async {
		let url = makeTempPDF(named: "toremove.pdf")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		try? await Task.sleep(nanoseconds: 200_000_000)
		XCTAssertEqual(store.items.count, 1)

		let item = store.items.first!
		store.remove(item)
		XCTAssertTrue(store.items.isEmpty)
	}

	func testRemoveByIDs() async {
		let url1 = makeTempPDF(named: "r1.pdf")
		let url2 = makeTempPDF(named: "r2.pdf")
		defer {
			try? FileManager.default.removeItem(at: url1)
			try? FileManager.default.removeItem(at: url2)
		}

		store.add(urls: [url1, url2])
		try? await Task.sleep(nanoseconds: 200_000_000)
		XCTAssertEqual(store.items.count, 2)

		let ids = Set(store.items.map { $0.id })
		store.remove(ids: ids)
		XCTAssertTrue(store.items.isEmpty)
	}

	// MARK: - Duplicate Detection

	func testAddDuplicateURLIsRejected() async {
		let url = makeTempPDF(named: "dup.pdf")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		try? await Task.sleep(nanoseconds: 200_000_000)
		XCTAssertEqual(store.items.count, 1)

		// Add the same URL again
		store.add(urls: [url])
		try? await Task.sleep(nanoseconds: 200_000_000)
		XCTAssertEqual(store.items.count, 1, "Duplicate URL should not be added")
	}

	// MARK: - Sort Order

	func testItemsSortedByDateDescending() async {
		let url1 = makeTempPDF(named: "first.pdf")
		let url2 = makeTempPDF(named: "second.pdf")
		defer {
			try? FileManager.default.removeItem(at: url1)
			try? FileManager.default.removeItem(at: url2)
		}

		store.add(urls: [url1])
		try? await Task.sleep(nanoseconds: 200_000_000)
		store.add(urls: [url2])
		try? await Task.sleep(nanoseconds: 200_000_000)

		XCTAssertEqual(store.items.count, 2)
		// Most recently added should be first
		XCTAssertEqual(store.items.first?.url, url2)
	}

	// MARK: - Persistence (debounced)

	func testFlushPendingPersistence() async {
		let url = makeTempPDF(named: "persist.pdf")
		defer { try? FileManager.default.removeItem(at: url) }

		store.add(urls: [url])
		try? await Task.sleep(nanoseconds: 200_000_000)
		XCTAssertEqual(store.items.count, 1)

		// Flush should not crash
		store.flushPendingPersistence()
	}

	// MARK: - Helpers

	private func makeTempPDF(named: String) -> URL {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(named)
		try? "%PDF-1.4\n%%EOF".data(using: .utf8)?.write(to: url)
		return url
	}
}
