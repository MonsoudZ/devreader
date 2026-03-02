import Foundation
import Combine
import os.log

/// Simple background persistence service for batch operations
@MainActor
class SimpleBackgroundPersistenceService: ObservableObject {
    static let shared = SimpleBackgroundPersistenceService()
    
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentOperation: String = ""

    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "BackgroundPersistence")

    /// Pending items to save after the current operation finishes
    private var pendingLibraryItems: [LibraryItem]?

    private init() {}

    // MARK: - Batch Operations

    /// Save library items in background to prevent UI blocking.
    /// If a save is already in progress, queues the latest items to save when it finishes.
    func saveLibraryItems(_ items: [LibraryItem]) async {
        if isProcessing {
            // Queue the latest items so they're saved when the current op finishes
            pendingLibraryItems = items
            return
        }

        isProcessing = true
        progress = 0.0
        currentOperation = "Saving library items..."

        // Use background queue for large operations
        await Task.detached(priority: .utility) {
            let envelope = LibraryEnvelope(items: items)
            do {
                try JSONStorageService.save(envelope, to: JSONStorageService.libraryPath())
            } catch {
                await MainActor.run {
                    logError(AppLog.app, "Failed to save library items in background: \(error)")
                }
            }
        }.value

        // Complete
        isProcessing = false
        progress = 1.0
        currentOperation = "Save completed"

        // If new items arrived while we were saving, save them now
        if let pending = pendingLibraryItems {
            pendingLibraryItems = nil
            await saveLibraryItems(pending)
        }
    }
    
    /// Import multiple PDFs with background processing
    func importPDFs(_ urls: [URL]) async -> [LibraryItem] {
        guard !isProcessing else { return [] }
        
        isProcessing = true
        progress = 0.0
        currentOperation = "Importing PDFs..."
        
        let importedItems = await Task.detached(priority: .userInitiated) { () -> [LibraryItem] in
            return urls.compactMap { url in
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                
                let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                return LibraryItem(
                    url: url,
                    title: url.lastPathComponent,
                    fileSize: fileSize,
                    addedDate: Date(),
                    lastOpened: nil
                )
            }
        }.value
        
        // Complete
        isProcessing = false
        progress = 1.0
        currentOperation = "Import completed"
        
        return importedItems
    }
    
    /// Remove duplicate items with background processing
    func removeDuplicates(from items: [LibraryItem]) async -> [LibraryItem] {
        guard !isProcessing else { return items }
        
        isProcessing = true
        progress = 0.0
        currentOperation = "Removing duplicates..."
        
        let uniqueItems = await Task.detached(priority: .userInitiated) { () -> [LibraryItem] in
            var result: [LibraryItem] = []
            
            for item in items {
                // Use a simple comparison instead of isDuplicate to avoid MainActor issues
                let isDuplicate = result.contains { existingItem in
                    existingItem.url == item.url
                }
                
                if !isDuplicate {
                    result.append(item)
                }
            }
            
            return result
        }.value
        
        // Complete
        isProcessing = false
        progress = 1.0
        currentOperation = "Deduplication completed"
        
        return uniqueItems
    }
}
