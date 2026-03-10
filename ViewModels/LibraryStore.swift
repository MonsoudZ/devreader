import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
	@Published var items: [LibraryItem] = []
	@Published var isProcessing: Bool = false
	@Published var processingProgress: Double = 0.0
	@Published var currentOperation: String = ""

	/// Recently removed items that can be restored via undo.
	@Published private(set) var recentlyRemoved: [LibraryItem] = []
	private static let maxRecentlyRemoved = 20

	private let key = "DevReader.Library.v1"
	let backgroundService: LibraryPersistenceService
	let loadingStateManager: LoadingStateManager
	private var persister: DebouncedPersister?
	private var isRestoring = false

	init(backgroundService: LibraryPersistenceService = .shared,
		 loadingStateManager: LoadingStateManager = .shared) {
		self.backgroundService = backgroundService
		self.loadingStateManager = loadingStateManager
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
		loadingStateManager.startLoading(.general, message: "Adding PDFs to library...")
		
		Task {
			// Use background service for large imports
			if urls.count > 10 {
				await addLargeBatch(urls)
			} else {
				await addSmallBatch(urls)
			}
			
			loadingStateManager.stopLoading(.general)
		}
	}
	
	private func addSmallBatch(_ urls: [URL]) async {
		let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
		let newItems = pdfs.map { url in
			LibraryItem(
				url: url,
				securityScopedBookmark: LibraryItem(url: url).createSecurityScopedBookmark(),
				title: url.lastPathComponent,
				fileSize: getFileSize(for: url),
				addedDate: Date(),
				lastOpened: nil
			)
		}

		// O(1) lookups for duplicate detection
		let existingURLs = Set(items.map { $0.url.standardizedFileURL })
		let existingFingerprints = Set(items.compactMap { item -> String? in
			guard item.fileSize > 0 else { return nil }
			return "\(item.title)|\(item.fileSize)"
		})
		let existingBookmarks = Set(items.compactMap { $0.securityScopedBookmark })

		let uniqueNewItems = newItems.filter { newItem in
			// URL match (most common)
			guard !existingURLs.contains(newItem.url.standardizedFileURL) else { return false }
			// Bookmark match
			if let bk = newItem.securityScopedBookmark, existingBookmarks.contains(bk) { return false }
			// Filename + size match
			if newItem.fileSize > 0, existingFingerprints.contains("\(newItem.title)|\(newItem.fileSize)") { return false }
			return true
		}

		let merged = items + uniqueNewItems
		items = merged.sorted { $0.addedDate > $1.addedDate }
		SpotlightService.shared.indexLibraryItems(uniqueNewItems)
		schedulePersist()
	}

	private func addLargeBatch(_ urls: [URL]) async {
		// Use background service for large imports
		let importedItems = await backgroundService.importPDFs(urls)

		// Remove duplicates
		let uniqueItems = await backgroundService.removeDuplicates(from: items + importedItems)
		items = uniqueItems.sorted { $0.addedDate > $1.addedDate }
		schedulePersist()
	}

	func remove(_ item: LibraryItem) {
		loadingStateManager.startLoading(.general, message: "Removing PDF from library...")
		SpotlightService.shared.deindexLibraryItem(item)
		EnhancedPersistenceService.shared.clearData(for: item.url)
		items.removeAll { $0.id == item.id }
		pushRecentlyRemoved([item])
		schedulePersist()
		loadingStateManager.stopLoading(.general)
	}

	func remove(ids: Set<LibraryItem.ID>) {
		loadingStateManager.startLoading(.general, message: "Removing PDFs from library...")
		SpotlightService.shared.deindexLibraryItems(ids)
		let removedItems = items.filter { ids.contains($0.id) }
		for item in removedItems {
			EnhancedPersistenceService.shared.clearData(for: item.url)
		}
		items.removeAll { ids.contains($0.id) }
		pushRecentlyRemoved(removedItems)
		schedulePersist()
		loadingStateManager.stopLoading(.general)
	}

	/// Restore a recently removed item back into the library.
	func restoreItem(_ item: LibraryItem) {
		recentlyRemoved.removeAll { $0.id == item.id }
		items.append(item)
		items.sort { $0.addedDate > $1.addedDate }
		SpotlightService.shared.indexLibraryItems([item])
		schedulePersist()
	}

	/// Restore all recently removed items.
	func restoreAllRecentlyRemoved() {
		let toRestore = recentlyRemoved
		recentlyRemoved.removeAll()
		items.append(contentsOf: toRestore)
		items.sort { $0.addedDate > $1.addedDate }
		SpotlightService.shared.indexLibraryItems(toRestore)
		schedulePersist()
	}

	func clearRecentlyRemoved() {
		recentlyRemoved.removeAll()
	}

	private func pushRecentlyRemoved(_ removedItems: [LibraryItem]) {
		recentlyRemoved.insert(contentsOf: removedItems, at: 0)
		if recentlyRemoved.count > Self.maxRecentlyRemoved {
			recentlyRemoved = Array(recentlyRemoved.prefix(Self.maxRecentlyRemoved))
		}
	}

	func refreshItem(_ item: LibraryItem) {
		// Update item with current file information, preserving identity
		if let index = items.firstIndex(where: { $0.id == item.id }) {
			let updatedItem = LibraryItem(
				id: item.id,
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
			schedulePersist()
		}
	}

	/// Refresh the security-scoped bookmark for an item when its resolved URL differs from the stored URL.
	func refreshBookmark(for item: LibraryItem, resolvedURL: URL) {
		guard let index = items.firstIndex(where: { $0.id == item.id }),
			  resolvedURL != item.url else { return }
		let newBookmark = LibraryItem(url: resolvedURL).createSecurityScopedBookmark()
		let updated = LibraryItem(
			id: item.id,
			url: resolvedURL,
			securityScopedBookmark: newBookmark,
			title: item.title,
			author: item.author,
			pageCount: item.pageCount,
			fileSize: item.fileSize,
			addedDate: item.addedDate,
			lastOpened: item.lastOpened,
			tags: item.tags,
			isPinned: item.isPinned,
			thumbnailData: item.thumbnailData
		)
		items[index] = updated
		schedulePersist()
	}

	// MARK: - Debounced Persistence

	private func schedulePersist() {
		guard !isRestoring else { return }
		if persister == nil {
			persister = DebouncedPersister(delay: 0.5) { [weak self] in
				self?.persistNow()
			}
		}
		persister?.schedule()
	}

	/// Immediately flush any pending debounced persistence (call on lifecycle events).
	func flushPendingPersistence() {
		persister?.flush()
	}

	private func persistNow() {
		// Use background persistence for large datasets
		if items.count > 100 {
			Task {
				await backgroundService.saveLibraryItems(items)
			}
		} else {
			// Use synchronous persistence for small datasets
			let envelope = LibraryEnvelope(items: items)
			do {
				try PersistenceService.saveCodable(envelope, forKey: key)
			} catch {
				logError(AppLog.app, "Library persist failed: \(error.localizedDescription)")
			}
		}
	}

	private func restore() {
		isRestoring = true
		defer { isRestoring = false }

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
			do {
				try PersistenceService.saveCodable(envelope, forKey: key)
			} catch {
				logError(AppLog.persistence, "Library migration save failed: \(error.localizedDescription)")
			}
			return
		}

		// Fallback: check JSONStorageService path (used by background service for large datasets)
		if let envelope = JSONStorageService.loadOptional(LibraryEnvelope.self, from: JSONStorageService.libraryPath()) {
			items = envelope.items
			// Migrate back to PersistenceService so future restores find it immediately
			do {
				try PersistenceService.saveCodable(envelope, forKey: key)
			} catch {
				logError(AppLog.persistence, "Library migration save failed: \(error.localizedDescription)")
			}
		}
	}
	
	private func getFileSize(for url: URL) -> Int64 {
		let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
		return attributes[.size] as? Int64 ?? 0
	}
}
