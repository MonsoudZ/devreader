import Foundation
import Combine
import os.log

/// Manages saved signatures and persistence
@MainActor
final class SignatureStore: ObservableObject {
	@Published var signatures: [SignatureItem] = []

	private let persistenceService: SignaturePersistenceProtocol
	private var persister: DebouncedPersister?

	init(persistenceService: SignaturePersistenceProtocol? = nil) {
		self.persistenceService = persistenceService ?? SignaturePersistenceService()
		load()
	}

	// MARK: - Signature Management

	func add(_ signature: SignatureItem) {
		signatures.append(signature)
		saveSignatures()
	}

	func delete(_ signature: SignatureItem) {
		signatures.removeAll { $0.id == signature.id }
		saveSignatures()
	}

	func load() {
		signatures = persistenceService.loadSignatures()
	}

	// MARK: - Persistence

	private func schedulePersist() {
		if persister == nil {
			persister = DebouncedPersister { [weak self] in
				self?.saveSignatures()
			}
		}
		persister?.schedule()
	}

	func flushPendingPersistence() {
		persister?.flush()
	}

	private func saveSignatures() {
		do {
			try persistenceService.saveSignatures(signatures)
		} catch {
			logError(AppLog.app, "Failed to save signatures: \(error)")
		}
	}

	func clearAllData() {
		signatures.removeAll()
		persistenceService.clearAllData()
	}
}
