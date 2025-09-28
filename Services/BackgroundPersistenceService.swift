import Foundation
import Combine
import os.log

/// Background persistence service for batch operations to prevent UI blocking
@MainActor
class BackgroundPersistenceService: ObservableObject {
    static let shared = BackgroundPersistenceService()
    
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentOperation: String = ""
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "BackgroundPersistence")
    private let persistenceQueue = DispatchQueue(label: "com.devreader.persistence", qos: .utility)
    private var currentTask: Task<[LibraryItem], Never>?
    
    private init() {}
    
    // MARK: - Batch Operations
    
    /// Save library items in background to prevent UI blocking
    func saveLibraryItems(_ items: [LibraryItem]) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        progress = 0.0
        currentOperation = "Saving library items..."
        
        currentTask = Task<[LibraryItem], Never> {
            await performBackgroundSave(items)
            return items
        }
        
        _ = await currentTask?.value
    }
    
    /// Import multiple PDFs with background processing
    func importPDFs(_ urls: [URL]) async -> [LibraryItem] {
        guard !isProcessing else { return [] }
        
        isProcessing = true
        progress = 0.0
        currentOperation = "Importing PDFs..."
        
        currentTask = Task<[LibraryItem], Never> {
            return await performBackgroundImport(urls)
        }
        
        return await currentTask?.value ?? []
    }
    
    /// Remove duplicate items with background processing
    func removeDuplicates(from items: [LibraryItem]) async -> [LibraryItem] {
        guard !isProcessing else { return items }
        
        isProcessing = true
        progress = 0.0
        currentOperation = "Removing duplicates..."
        
        currentTask = Task<[LibraryItem], Never> {
            return await performBackgroundDeduplication(items)
        }
        
        return await currentTask?.value ?? items
    }
    
    // MARK: - Background Operations
    
    private func performBackgroundSave(_ items: [LibraryItem]) async {
        let totalItems = items.count
        
        for (index, item) in items.enumerated() {
            // Check if task was cancelled
            if Task.isCancelled { break }
            
            // Update progress
            await MainActor.run {
                progress = Double(index) / Double(totalItems)
                currentOperation = "Saving item \(index + 1) of \(totalItems)..."
            }
            
            // Save item in background
            await persistenceQueue.async {
            // Create security-scoped bookmark if needed
            if item.securityScopedBookmark == nil {
                let bookmark = await MainActor.run { item.createSecurityScopedBookmark() }
                // Note: We can't update the item here, but we can log it
                os_log("Created security-scoped bookmark for: %{public}@", log: self.logger, type: .debug, item.url.lastPathComponent)
            }
            }
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Save final envelope
        await persistenceQueue.async {
            let envelope = await MainActor.run { LibraryEnvelope(items: items) }
            let data = try? JSONEncoder().encode(envelope)
            if let data = data {
                let url = JSONStorageService.libraryPath()
                try? data.write(to: url)
            }
        }
        
        // Complete
        await MainActor.run {
            isProcessing = false
            progress = 1.0
            currentOperation = "Save completed"
        }
    }
    
    private func performBackgroundImport(_ urls: [URL]) async -> [LibraryItem] {
        var importedItems: [LibraryItem] = []
        let totalURLs = urls.count
        
        for (index, url) in urls.enumerated() {
            // Check if task was cancelled
            if Task.isCancelled { break }
            
            // Update progress
            await MainActor.run {
                progress = Double(index) / Double(totalURLs)
                currentOperation = "Importing \(index + 1) of \(totalURLs)..."
            }
            
            // Process URL in background
            let item = await persistenceQueue.async {
                return self.createLibraryItem(from: url)
            }
            
            if let item = item {
                importedItems.append(item)
            }
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        // Complete
        await MainActor.run {
            isProcessing = false
            progress = 1.0
            currentOperation = "Import completed"
        }
        
        return importedItems
    }
    
    private func performBackgroundDeduplication(_ items: [LibraryItem]) async -> [LibraryItem] {
        let totalItems = items.count
        var uniqueItems: [LibraryItem] = []
        var processedCount = 0
        
        for item in items {
            // Check if task was cancelled
            if Task.isCancelled { break }
            
            // Update progress
            await MainActor.run {
                progress = Double(processedCount) / Double(totalItems)
                currentOperation = "Processing item \(processedCount + 1) of \(totalItems)..."
            }
            
            // Check for duplicates in background
            let isDuplicate = await persistenceQueue.async {
                return uniqueItems.contains { existingItem in
                    item.isDuplicate(of: existingItem)
                }
            }
            
            if !isDuplicate {
                uniqueItems.append(item)
            }
            
            processedCount += 1
            
            // Small delay to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Complete
        await MainActor.run {
            isProcessing = false
            progress = 1.0
            currentOperation = "Deduplication completed"
        }
        
        return uniqueItems
    }
    
    // MARK: - Helper Methods
    
    private func createLibraryItem(from url: URL) -> LibraryItem? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let fileSize = attributes[.size] as? Int64 ?? 0
        let modificationDate = attributes[.modificationDate] as? Date ?? Date()
        
        // Create security-scoped bookmark
        let bookmark = createSecurityScopedBookmark(for: url)
        
        return LibraryItem(
            url: url,
            securityScopedBookmark: bookmark,
            title: url.lastPathComponent,
            fileSize: fileSize,
            addedDate: Date(),
            lastOpened: nil
        )
    }
    
    private func createSecurityScopedBookmark(for url: URL) -> Data? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            return try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadKey], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            os_log("Failed to create security-scoped bookmark: %{public}@", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Task Management
    
    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        
        isProcessing = false
        progress = 0.0
        currentOperation = "Operation cancelled"
    }
    
    func isTaskRunning() -> Bool {
        return isProcessing && currentTask != nil
    }
}

// MARK: - Extensions

extension DispatchQueue {
    func async<T>(_ block: @escaping () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            async {
                let result = block()
                continuation.resume(returning: result)
            }
        }
    }
}
