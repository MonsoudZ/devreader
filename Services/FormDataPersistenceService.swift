import Foundation

// MARK: - Form Field Entry Model

/// Persisted form field value for a single widget annotation in a PDF.
struct FormFieldEntry: Codable, Sendable {
	let fieldName: String
	let pageIndex: Int
	let value: String
	let fieldType: String
}

// MARK: - Protocol

/// Protocol for form data persistence to enable dependency injection and testing.
@MainActor
protocol FormDataPersistenceProtocol {
	func saveFormData(_ entries: [FormFieldEntry], for url: URL) throws
	func loadFormData(for url: URL) -> [FormFieldEntry]
	func clearFormData(for url: URL)
}

// MARK: - Production Implementation

/// Production implementation using EnhancedPersistenceService.
@MainActor
class FormDataPersistenceService: FormDataPersistenceProtocol {
	private let persistenceService: EnhancedPersistenceService
	private let formDataKey = "DevReader.FormData.v1"

	init(persistenceService: EnhancedPersistenceService = .shared) {
		self.persistenceService = persistenceService
	}

	func saveFormData(_ entries: [FormFieldEntry], for url: URL) throws {
		try persistenceService.saveCodable(entries, forKey: formDataKey, url: url)
	}

	func loadFormData(for url: URL) -> [FormFieldEntry] {
		persistenceService.loadCodableWithMigration([FormFieldEntry].self, forKey: formDataKey, url: url) ?? []
	}

	func clearFormData(for url: URL) {
		let key = persistenceService.generateKey(formDataKey, for: url)
		persistenceService.deleteKey(key)
	}
}
