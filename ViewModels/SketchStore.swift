import Foundation
import Combine
import SwiftUI
import os.log

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
        createSketch(for: pdfURL, pageIndex: pageIndex, canvasData: Data(), strokesData: nil)
    }

    func createSketch(for pdfURL: URL, pageIndex: Int, canvasData: Data, strokesData: Data?) {
        let sketch = SketchItem(
            id: UUID(),
            pdfURL: pdfURL,
            pageIndex: pageIndex,
            title: "Sketch \(sketches.count + 1)",
            createdDate: Date(),
            lastModified: Date(),
            canvasData: canvasData,
            strokesData: strokesData,
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
            logError(AppLog.app, "Failed to save sketches: \(error)")
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

