import Foundation
import Combine
import SwiftUI
import os.log

/// Manages sketch data and persistence
@MainActor
final class SketchStore: ObservableObject {
    @Published var sketches: [SketchItem] = []
    @Published var currentSketch: SketchItem?
    
    private let persistenceService: SketchPersistenceProtocol
    nonisolated(unsafe) private var persistWorkItem: DispatchWorkItem?

    init(persistenceService: SketchPersistenceProtocol? = nil) {
        self.persistenceService = persistenceService ?? SketchPersistenceService()
        loadSketches()
    }

    deinit {
        persistWorkItem?.cancel()
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
            schedulePersist()
        }
    }
    
    func deleteSketch(_ sketch: SketchItem) {
        sketches.removeAll { $0.id == sketch.id }
        if currentSketch?.id == sketch.id {
            currentSketch = nil
        }
        saveSketches()
    }
    
    private func sanitizedFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.unicodeScalars.filter { !invalidChars.contains($0) }
        let result = String(String.UnicodeScalarView(sanitized))
        return result.isEmpty ? "untitled" : result
    }

    func exportSketch(_ sketch: SketchItem) -> URL? {
        guard let image = NSImage(data: sketch.canvasData) else { return nil }

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFilename(sketch.title)).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: exportURL)
            return exportURL
        } catch {
            logError(AppLog.app, "Failed to export sketch: \(error)")
            return nil
        }
    }
    
    func getSketches(for pdfURL: URL) -> [SketchItem] {
        return sketches.filter { $0.pdfURL == pdfURL }
    }
    
    func getSketches(for pdfURL: URL, pageIndex: Int) -> [SketchItem] {
        return sketches.filter { $0.pdfURL == pdfURL && $0.pageIndex == pageIndex }
    }
    
    // MARK: - Persistence

    private func schedulePersist() {
        persistWorkItem?.cancel()
        let workItem = DispatchWorkItem { @Sendable [weak self] in
            Task { @MainActor in
                self?.saveSketches()
            }
        }
        persistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func flushPendingPersistence() {
        if let workItem = persistWorkItem {
            workItem.cancel()
            persistWorkItem = nil
            saveSketches()
        }
    }

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

