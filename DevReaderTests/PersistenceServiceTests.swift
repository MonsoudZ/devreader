import XCTest
@testable import DevReader

final class PersistenceServiceTests: XCTestCase {
    struct Dummy: Codable, Equatable { let a: Int; let b: String }

    func testSaveLoadDeleteCodable() {
        let key = "Test.Dummy.\(UUID().uuidString)"
        let value = Dummy(a: 42, b: "hello")
        PersistenceService.saveCodable(value, forKey: key)
        let loaded: Dummy? = PersistenceService.loadCodable(Dummy.self, forKey: key)
        XCTAssertEqual(loaded, value)
        PersistenceService.delete(forKey: key)
        let afterDelete: Dummy? = PersistenceService.loadCodable(Dummy.self, forKey: key)
        XCTAssertNil(afterDelete)
    }

    func testSaveLoadInt() {
        let key = "Test.Int.\(UUID().uuidString)"
        PersistenceService.saveInt(123, forKey: key)
        let loaded = PersistenceService.loadInt(forKey: key)
        XCTAssertEqual(loaded, 123)
        PersistenceService.delete(forKey: key)
        XCTAssertNil(PersistenceService.loadInt(forKey: key))
    }
}


