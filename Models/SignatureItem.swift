import Foundation

nonisolated struct SignatureItem: Codable, Identifiable, Hashable, Sendable {
	let id: UUID
	var name: String
	let createdDate: Date
	let type: SignatureType
	let imageData: Data  // PNG

	nonisolated enum SignatureType: String, Codable, Sendable {
		case drawn, typed
	}

	init(id: UUID = UUID(), name: String, createdDate: Date = Date(), type: SignatureType, imageData: Data) {
		self.id = id
		self.name = name
		self.createdDate = createdDate
		self.type = type
		self.imageData = imageData
	}
}
