import Foundation
import PDFKit
import os.log

/// Manages PDF page loading and memory optimization
@MainActor
class PDFPageManager: ObservableObject {
    static let shared = PDFPageManager()
    
    @Published var loadedPages: Set<Int> = []
    @Published var visiblePageRange: ClosedRange<Int> = 0...0
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "PDFPageManager")
    private var pageCache: [Int: PDFPage] = [:]
    private let maxCachedPages = 10
    private var currentDocument: PDFDocument?
    
    private init() {}
    
    // MARK: - Page Management
    
    func setDocument(_ document: PDFDocument?) {
        currentDocument = document
        clearCache()
    }
    
    func updateVisibleRange(_ range: ClosedRange<Int>) {
        visiblePageRange = range
        
        // Load pages in visible range
        for pageIndex in range {
            loadPageIfNeeded(pageIndex)
        }
        
        // Unload pages outside visible range
        unloadDistantPages()
    }
    
    private func loadPageIfNeeded(_ pageIndex: Int) {
        guard let document = currentDocument,
              pageIndex >= 0,
              pageIndex < document.pageCount,
              !loadedPages.contains(pageIndex) else { return }
        
        // Load the page
        if let page = document.page(at: pageIndex) {
            pageCache[pageIndex] = page
            loadedPages.insert(pageIndex)
            
            os_log("Loaded page %d", log: logger, type: .debug, pageIndex)
        }
    }
    
    private func unloadDistantPages() {
        let buffer = 2 // Keep 2 pages before and after visible range
        let keepRange = (visiblePageRange.lowerBound - buffer)...(visiblePageRange.upperBound + buffer)
        
        let pagesToUnload = loadedPages.filter { !keepRange.contains($0) }
        
        for pageIndex in pagesToUnload {
            unloadPage(pageIndex)
        }
    }
    
    private func unloadPage(_ pageIndex: Int) {
        pageCache.removeValue(forKey: pageIndex)
        loadedPages.remove(pageIndex)
        
        os_log("Unloaded page %d", log: logger, type: .debug, pageIndex)
    }
    
    // MARK: - Memory Management
    
    func clearCache() {
        pageCache.removeAll()
        loadedPages.removeAll()
        
        os_log("Cleared PDF page cache", log: logger, type: .debug)
    }
    
    func optimizeForMemoryPressure() {
        // Keep only visible pages
        let visiblePages = Set(visiblePageRange)
        let pagesToUnload = loadedPages.subtracting(visiblePages)
        
        for pageIndex in pagesToUnload {
            unloadPage(pageIndex)
        }
        
        os_log("Optimized page cache for memory pressure", log: logger, type: .info)
    }
    
    // MARK: - Statistics
    
    func getCacheStatistics() -> (loaded: Int, cached: Int, visible: Int) {
        return (
            loaded: loadedPages.count,
            cached: pageCache.count,
            visible: visiblePageRange.count
        )
    }
}
