import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
	@Published var items: [LibraryItem] = [] { didSet { persist() } }
	private let key = "DevReader.Library.v1"

	init() { restore() }

	func add(urls: [URL]) {
		LoadingStateManager.shared.startLoading(.general, message: "Adding PDFs to library...")
		let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
		let newItems = pdfs.map(LibraryItem.init(url:))
		let existing = Set(items.map { $0.url })
		let merged = items + newItems.filter { !existing.contains($0.url) }
		items = merged.sorted { $0.addedAt > $1.addedAt }
		LoadingStateManager.shared.stopLoading(.general)
	}

	func remove(_ item: LibraryItem) { 
		LoadingStateManager.shared.startLoading(.general, message: "Removing PDF from library...")
		items.removeAll { $0.id == item.id }
		LoadingStateManager.shared.stopLoading(.general)
	}

	func remove(ids: Set<LibraryItem.ID>) { 
		LoadingStateManager.shared.startLoading(.general, message: "Removing PDFs from library...")
		items.removeAll { ids.contains($0.id) }
		LoadingStateManager.shared.stopLoading(.general)
	}

	private func persist() {
		PersistenceService.saveCodable(items, forKey: key)
	}

	private func restore() {
		if let restored: [LibraryItem] = PersistenceService.loadCodable([LibraryItem].self, forKey: key) {
			items = restored
		}
	}
}
