import Foundation
import Combine
import SwiftUI

/// Manages sketch data and persistence
@MainActor
class SketchStore: ObservableObject {
    @Published var sketches: [SketchItem] = []
    @Published var currentSketch: SketchItem?
    
    private let persistenceService: SketchPersistenceProtocol
    
    init(persistenceService: SketchPersistenceProtocol? = nil) {
        self.persistenceService = persistenceService ?? SketchPersistenceService()
        loadSketches()
    }
    
    // MARK: - Sketch Management
    
    func createSketch(for pdfURL: URL, pageIndex: Int) {
        let sketch = SketchItem(
            id: UUID(),
            pdfURL: pdfURL,
            pageIndex: pageIndex,
            title: "Sketch \(sketches.count + 1)",
            createdDate: Date(),
            lastModified: Date(),
            canvasData: Data(),
            isExported: false
        )
        
        sketches.append(sketch)
        currentSketch = sketch
        saveSketches()
    }
    
    func updateCurrentSketch(_ canvasData: Data) {
        guard var sketch = currentSketch else { return }
        
        sketch.canvasData = canvasData
        sketch.lastModified = Date()
        
        if let index = sketches.firstIndex(where: { $0.id == sketch.id }) {
            sketches[index] = sketch
            currentSketch = sketch
            saveSketches()
        }
    }
    
    func deleteSketch(_ sketch: SketchItem) {
        sketches.removeAll { $0.id == sketch.id }
        if currentSketch?.id == sketch.id {
            currentSketch = nil
        }
        saveSketches()
    }
    
    func exportSketch(_ sketch: SketchItem) -> URL? {
        // Export sketch as image
        guard let image = NSImage(data: sketch.canvasData) else { return nil }
        
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sketch.title).png")
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        try? pngData.write(to: exportURL)
        return exportURL
    }
    
    func getSketches(for pdfURL: URL) -> [SketchItem] {
        return sketches.filter { $0.pdfURL == pdfURL }
    }
    
    func getSketches(for pdfURL: URL, pageIndex: Int) -> [SketchItem] {
        return sketches.filter { $0.pdfURL == pdfURL && $0.pageIndex == pageIndex }
    }
    
    // MARK: - Persistence
    
    private func saveSketches() {
        do {
            try persistenceService.saveSketches(sketches)
        } catch {
            print("Failed to save sketches: \(error)")
        }
    }
    
    private func loadSketches() {
        sketches = persistenceService.loadSketches()
    }
    
    func clearAllData() {
        sketches.removeAll()
        currentSketch = nil
        persistenceService.clearAllData()
    }
}

// MARK: - Sketch Item Model

struct SketchItem: Identifiable, Codable {
    let id: UUID
    let pdfURL: URL
    let pageIndex: Int
    var title: String
    let createdDate: Date
    var lastModified: Date
    var canvasData: Data
    var isExported: Bool
    
    init(id: UUID = UUID(), pdfURL: URL, pageIndex: Int, title: String, createdDate: Date, lastModified: Date, canvasData: Data, isExported: Bool = false) {
        self.id = id
        self.pdfURL = pdfURL
        self.pageIndex = pageIndex
        self.title = title
        self.createdDate = createdDate
        self.lastModified = lastModified
        self.canvasData = canvasData
        self.isExported = isExported
    }
}

// MARK: - Sketch Persistence Protocol

protocol SketchPersistenceProtocol {
    func saveSketches(_ sketches: [SketchItem]) throws
    func loadSketches() -> [SketchItem]
    func clearAllData()
}

class SketchPersistenceService: SketchPersistenceProtocol {
    private let persistenceService = EnhancedPersistenceService.shared
    private let sketchesKey = "DevReader.Sketches.v1"
    
    func saveSketches(_ sketches: [SketchItem]) throws {
        try persistenceService.saveCodable(sketches, forKey: sketchesKey)
    }
    
    func loadSketches() -> [SketchItem] {
        return persistenceService.loadCodable([SketchItem].self, forKey: sketchesKey) ?? []
    }
    
    func clearAllData() {
        persistenceService.clearAllData()
    }
}
