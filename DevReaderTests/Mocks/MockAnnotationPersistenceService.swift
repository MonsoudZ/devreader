import Foundation
@testable import DevReader

@MainActor
final class MockAnnotationPersistenceService: AnnotationPersistenceProtocol {
    var annotations: [URL: [PDFAnnotationData]] = [:]
    var shouldThrowError = false
    var saveCount = 0

    func saveAnnotations(_ annotations: [PDFAnnotationData], for url: URL) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        self.annotations[url] = annotations
        saveCount += 1
    }

    func loadAnnotations(for url: URL) -> [PDFAnnotationData] {
        return annotations[url] ?? []
    }

    func clearAnnotations(for url: URL) {
        annotations.removeValue(forKey: url)
    }
}
