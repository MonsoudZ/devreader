import XCTest
@testable import DevReader

// MARK: - Mock

@MainActor
final class MockSignaturePersistenceService: SignaturePersistenceProtocol {
    var signatures: [SignatureItem] = []
    var saveCallCount = 0
    var shouldThrowError = false

    func saveSignatures(_ signatures: [SignatureItem]) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.signatures = signatures
        saveCallCount += 1
    }

    func loadSignatures() -> [SignatureItem] {
        return signatures
    }

    func clearAllData() {
        signatures.removeAll()
        saveCallCount = 0
    }
}

// MARK: - Tests

@MainActor
final class SignatureStoreTests: XCTestCase {
    var store: SignatureStore!
    var mockPersistence: MockSignaturePersistenceService!

    override func setUp() async throws {
        mockPersistence = MockSignaturePersistenceService()
        store = SignatureStore(persistenceService: mockPersistence)
    }

    override func tearDown() async throws {
        store = nil
        mockPersistence = nil
    }

    // MARK: - Add

    func testAddSignature() {
        let sig = SignatureItem(name: "My Sig", type: .drawn, imageData: Data([0x01, 0x02]))

        store.add(sig)
        store.flushPendingPersistence()

        XCTAssertEqual(store.signatures.count, 1)
        XCTAssertEqual(store.signatures.first?.name, "My Sig")
        XCTAssertEqual(store.signatures.first?.type, .drawn)
        XCTAssertEqual(store.signatures.first?.imageData, Data([0x01, 0x02]))
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
    }

    func testAddMultipleSignatures() {
        let sig1 = SignatureItem(name: "Drawn", type: .drawn, imageData: Data([0x01]))
        let sig2 = SignatureItem(name: "Typed", type: .typed, imageData: Data([0x02]))

        store.add(sig1)
        store.add(sig2)
        store.flushPendingPersistence()

        XCTAssertEqual(store.signatures.count, 2)
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
    }

    // MARK: - Delete

    func testDeleteSignature() {
        let sig = SignatureItem(name: "ToDelete", type: .drawn, imageData: Data([0xFF]))
        store.add(sig)
        store.flushPendingPersistence()

        store.delete(sig)
        store.flushPendingPersistence()

        XCTAssertTrue(store.signatures.isEmpty)
        XCTAssertEqual(mockPersistence.saveCallCount, 2)
    }

    func testDeleteNonexistentSignatureIsNoOp() {
        let sig1 = SignatureItem(name: "Keep", type: .drawn, imageData: Data([0x01]))
        store.add(sig1)

        let sig2 = SignatureItem(name: "Ghost", type: .typed, imageData: Data([0x02]))
        store.delete(sig2)

        XCTAssertEqual(store.signatures.count, 1)
        XCTAssertEqual(store.signatures.first?.name, "Keep")
    }

    // MARK: - Rename

    func testRenameSignatureViaMutation() {
        // SignatureItem.name is a var, so the store's array can be mutated externally
        // through the published property. Test that the store reflects name changes
        // when the item is re-added after modification.
        let sig = SignatureItem(name: "Original", type: .drawn, imageData: Data([0x01]))
        store.add(sig)

        // Simulate rename by deleting old and adding renamed copy
        var renamed = sig
        renamed.name = "Renamed"
        store.delete(sig)
        store.add(renamed)

        XCTAssertEqual(store.signatures.count, 1)
        XCTAssertEqual(store.signatures.first?.name, "Renamed")
    }

    // MARK: - Persistence (save and reload)

    func testLoadOnInit() {
        let preloaded = SignatureItem(name: "Preloaded", type: .typed, imageData: Data([0xAA]))
        let freshMock = MockSignaturePersistenceService()
        freshMock.signatures = [preloaded]

        let newStore = SignatureStore(persistenceService: freshMock)
        addTeardownBlock { [newStore] in _ = newStore }

        XCTAssertEqual(newStore.signatures.count, 1)
        XCTAssertEqual(newStore.signatures.first?.name, "Preloaded")
    }

    func testPersistenceRoundTrip() {
        let sig = SignatureItem(name: "Persist Me", type: .drawn, imageData: Data([0xBB, 0xCC]))
        store.add(sig)
        store.flushPendingPersistence()

        XCTAssertEqual(mockPersistence.signatures.count, 1)
        XCTAssertEqual(mockPersistence.signatures.first?.name, "Persist Me")

        // Create a new store with the same mock to simulate reload
        let newStore = SignatureStore(persistenceService: mockPersistence)
        addTeardownBlock { [newStore] in _ = newStore }

        XCTAssertEqual(newStore.signatures.count, 1)
        XCTAssertEqual(newStore.signatures.first?.name, "Persist Me")
        XCTAssertEqual(newStore.signatures.first?.imageData, Data([0xBB, 0xCC]))
    }

    // MARK: - Clear All

    func testClearAllData() {
        store.add(SignatureItem(name: "A", type: .drawn, imageData: Data([0x01])))
        store.add(SignatureItem(name: "B", type: .typed, imageData: Data([0x02])))

        store.clearAllData()

        XCTAssertTrue(store.signatures.isEmpty)
    }
}
