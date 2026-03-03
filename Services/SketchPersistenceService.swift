import Foundation

protocol SketchPersistenceProtocol: Sendable {
    func saveSketches(_ sketches: [SketchItem]) throws
    func loadSketches() -> [SketchItem]
    func clearAllData()
}

final class SketchPersistenceService: SketchPersistenceProtocol, @unchecked Sendable {
    private let persistenceService = EnhancedPersistenceService.shared
    private let sketchesKey = "DevReader.Sketches.v1"

    func saveSketches(_ sketches: [SketchItem]) throws {
        try persistenceService.saveCodable(sketches, forKey: sketchesKey)
    }

    func loadSketches() -> [SketchItem] {
        return persistenceService.loadCodable([SketchItem].self, forKey: sketchesKey) ?? []
    }

    func clearAllData() {
        persistenceService.deleteKey(sketchesKey)
    }
}
