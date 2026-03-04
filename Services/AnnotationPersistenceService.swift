import Foundation

/// Protocol for annotation persistence to enable dependency injection and testing
@MainActor
protocol AnnotationPersistenceProtocol {
	func saveAnnotations(_ annotations: [PDFAnnotationData], for url: URL) throws
	func loadAnnotations(for url: URL) -> [PDFAnnotationData]
	func clearAnnotations(for url: URL)
}

/// Production implementation using EnhancedPersistenceService
@MainActor
class AnnotationPersistenceService: AnnotationPersistenceProtocol {
	private let persistenceService: EnhancedPersistenceService
	private let annotationsKey = "DevReader.Annotations.v1"

	init(persistenceService: EnhancedPersistenceService = .shared) {
		self.persistenceService = persistenceService
	}

	func saveAnnotations(_ annotations: [PDFAnnotationData], for url: URL) throws {
		try persistenceService.saveCodable(annotations, forKey: annotationsKey, url: url)
	}

	func loadAnnotations(for url: URL) -> [PDFAnnotationData] {
		persistenceService.loadCodableWithMigration([PDFAnnotationData].self, forKey: annotationsKey, url: url) ?? []
	}

	func clearAnnotations(for url: URL) {
		let key = persistenceService.generateKey(annotationsKey, for: url)
		persistenceService.deleteKey(key)
	}
}
