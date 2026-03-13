import Foundation

@MainActor
protocol SignaturePersistenceProtocol {
	func saveSignatures(_ signatures: [SignatureItem]) throws
	func loadSignatures() -> [SignatureItem]
	func clearAllData()
}

@MainActor
final class SignaturePersistenceService: SignaturePersistenceProtocol {
	private let persistenceService: EnhancedPersistenceService
	private let signaturesKey = "DevReader.Signatures.v1"

	init(persistenceService: EnhancedPersistenceService = .shared) {
		self.persistenceService = persistenceService
	}

	func saveSignatures(_ signatures: [SignatureItem]) throws {
		try persistenceService.saveCodable(signatures, forKey: signaturesKey)
	}

	func loadSignatures() -> [SignatureItem] {
		return persistenceService.loadCodable([SignatureItem].self, forKey: signaturesKey) ?? []
	}

	func clearAllData() {
		persistenceService.deleteKey(signaturesKey)
	}
}
