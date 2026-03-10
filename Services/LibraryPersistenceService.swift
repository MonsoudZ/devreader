import Foundation
import Combine
import os.log

/// Background persistence service for library batch operations (save, import, deduplicate)
@MainActor
class LibraryPersistenceService: ObservableObject {
    static let shared = LibraryPersistenceService()

    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentOperation: String = ""
    @Published var lastError: Error?

    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "BackgroundPersistence")

    /// Pending items to save after the current operation finishes
    private var pendingLibraryItems: [LibraryItem]?

    init() {}

    // MARK: - Batch Operations

    /// Save library items in background to prevent UI blocking.
    /// If a save is already in progress, queues the latest items to save when it finishes.
    @discardableResult
    func saveLibraryItems(_ items: [LibraryItem]) async -> Bool {
        if isProcessing {
            // Queue the latest items so they're saved when the current op finishes
            pendingLibraryItems = items
            return true
        }

        lastError = nil
        isProcessing = true
        progress = 0.0
        currentOperation = "Saving library items..."

        let envelope = LibraryEnvelope(items: items)
        let saveSucceeded: Bool = await Task.detached(priority: .utility) { @Sendable in
            do {
                try JSONStorageService.save(envelope, to: JSONStorageService.libraryPath())
                return true
            } catch {
                await MainActor.run {
                    logError(AppLog.app, "Failed to save library items in background: \(error)")
                }
                return false
            }
        }.value

        if !saveSucceeded {
            lastError = NSError(domain: "LibraryPersistence", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to save library items"])
        }

        progress = 1.0
        currentOperation = saveSucceeded ? "Save completed" : "Save failed"

        // Drain pending items before clearing isProcessing.
        // Safety: this block has no suspension points, so @MainActor guarantees atomic
        // execution — no other caller can interleave between extracting pending,
        // clearing the flag, and starting the recursive save.
        let pending = pendingLibraryItems
        pendingLibraryItems = nil
        isProcessing = false

        if let pending {
            return await saveLibraryItems(pending)
        } else if !saveSucceeded {
            // Re-queue failed items so they're retried on the next save call
            pendingLibraryItems = items
        }

        return saveSucceeded
    }

    /// Import multiple PDFs with background processing
    func importPDFs(_ urls: [URL]) async -> [LibraryItem] {
        guard !isProcessing else { return [] }

        lastError = nil
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

        let skippedCount = urls.count - importedItems.count
        if skippedCount > 0 {
            logError(AppLog.app, "Import skipped \(skippedCount) of \(urls.count) PDFs (files not found)")
        }

        // Complete
        isProcessing = false
        progress = 1.0
        currentOperation = "Imported \(importedItems.count) of \(urls.count) PDFs"

        return importedItems
    }

    /// Remove duplicate items with background processing
    func removeDuplicates(from items: [LibraryItem]) async -> [LibraryItem] {
        guard !isProcessing else { return items }

        lastError = nil
        isProcessing = true
        progress = 0.0
        currentOperation = "Removing duplicates..."

        let uniqueItems = await Task.detached(priority: .userInitiated) { () -> [LibraryItem] in
            var result: [LibraryItem] = []

            for item in items {
                let isDuplicate = result.contains { existingItem in
                    existingItem.url.standardizedFileURL == item.url.standardizedFileURL
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
