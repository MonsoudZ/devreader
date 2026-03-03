import Foundation
@testable import DevReader

final class MockSketchPersistenceService: SketchPersistenceProtocol, @unchecked Sendable {
    var sketches: [SketchItem] = []
    var saveCallCount = 0
    var shouldThrowError = false

    func saveSketches(_ sketches: [SketchItem]) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.sketches = sketches
        saveCallCount += 1
    }

    func loadSketches() -> [SketchItem] {
        return sketches
    }

    func clearAllData() {
        sketches.removeAll()
        saveCallCount = 0
    }
}
