import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
	@Published var items: [LibraryItem] = [] { didSet { persist() } }
	@Published var isProcessing: Bool = false
	@Published var processingProgress: Double = 0.0
	@Published var currentOperation: String = ""
	
	private let key = "DevReader.Library.v1"
	private let backgroundService = SimpleBackgroundPersistenceService.shared

	init() { 
		restore()
		setupBackgroundService()
	}
	
	private func setupBackgroundService() {
		// Monitor background service state
		backgroundService.$isProcessing
			.assign(to: &$isProcessing)
		
		backgroundService.$progress
			.assign(to: &$processingProgress)
		
		backgroundService.$currentOperation
			.assign(to: &$currentOperation)
	}

	func add(urls: [URL]) {
		LoadingStateManager.shared.startLoading(.general, message: "Adding PDFs to library...")
		
		Task {
			// Use background service for large imports
			if urls.count > 10 {
				await addLargeBatch(urls)
			} else {
				await addSmallBatch(urls)
			}
			
			LoadingStateManager.shared.stopLoading(.general)
		}
	}
	
	private func addSmallBatch(_ urls: [URL]) async {
		let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
		let newItems = pdfs.map { url in
			LibraryItem(
				url: url,
				title: url.lastPathComponent,
				fileSize: getFileSize(for: url),
				addedDate: Date(),
				lastOpened: nil
			)
		}
		
		// Remove duplicates using enhanced duplicate detection
		let uniqueNewItems = newItems.filter { newItem in
			!items.contains { existingItem in
				newItem.isDuplicate(of: existingItem)
			}
		}
		
		let merged = items + uniqueNewItems
		items = merged.sorted { $0.addedDate > $1.addedDate }
	}
	
	private func addLargeBatch(_ urls: [URL]) async {
		// Use background service for large imports
		let importedItems = await backgroundService.importPDFs(urls)
		
		// Remove duplicates
		let uniqueItems = await backgroundService.removeDuplicates(from: items + importedItems)
		items = uniqueItems.sorted { $0.addedDate > $1.addedDate }
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
	
	func removeDuplicates() {
		LoadingStateManager.shared.startLoading(.general, message: "Removing duplicates...")
		
		Task {
			let uniqueItems = await backgroundService.removeDuplicates(from: items)
			items = uniqueItems
			LoadingStateManager.shared.stopLoading(.general)
		}
	}
	
	func refreshItem(_ item: LibraryItem) {
		// Update item with current file information
		if let index = items.firstIndex(where: { $0.id == item.id }) {
			let updatedItem = LibraryItem(
				url: item.url,
				securityScopedBookmark: item.securityScopedBookmark,
				title: item.title,
				author: item.author,
				pageCount: item.pageCount,
				fileSize: getFileSize(for: item.url),
				addedDate: item.addedDate,
				lastOpened: item.lastOpened,
				tags: item.tags,
				isPinned: item.isPinned,
				thumbnailData: item.thumbnailData
			)
			items[index] = updatedItem
		}
	}

	private func persist() {
		// Use background persistence for large datasets
		if items.count > 100 {
			Task {
				await backgroundService.saveLibraryItems(items)
			}
		} else {
			// Use synchronous persistence for small datasets
			let envelope = LibraryEnvelope(items: items)
			PersistenceService.saveCodable(envelope, forKey: key)
		}
	}

	private func restore() {
		// Try to load as new envelope format first
		if let envelope: LibraryEnvelope = PersistenceService.loadCodable(LibraryEnvelope.self, forKey: key) {
			items = envelope.items
			return
		}
		
		// Fallback to old format for migration
		if let oldItems: [LibraryItem] = PersistenceService.loadCodable([LibraryItem].self, forKey: key) {
			items = oldItems
			// Migrate to new format
			let envelope = LibraryEnvelope(items: oldItems)
			PersistenceService.saveCodable(envelope, forKey: key)
		}
	}
	
	private func getFileSize(for url: URL) -> Int64 {
		let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
		return attributes[.size] as? Int64 ?? 0
	}
}
