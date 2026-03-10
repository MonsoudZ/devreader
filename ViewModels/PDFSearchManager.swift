import Foundation
@preconcurrency import PDFKit
import Combine
import AppKit

@MainActor
final class PDFSearchManager: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var searchIndex: Int = 0
    @Published var isSearching: Bool = false

    let selectionBridge: PDFSelectionBridge
    let loadingStateManager: LoadingStateManager
    let performanceMonitor: PerformanceMonitor
    private var searchTask: Task<Void, Never>?

    init(selectionBridge: PDFSelectionBridge = PDFSelectionBridge(),
         loadingStateManager: LoadingStateManager = .shared,
         performanceMonitor: PerformanceMonitor = .shared) {
        self.selectionBridge = selectionBridge
        self.loadingStateManager = loadingStateManager
        self.performanceMonitor = performanceMonitor
    }

    func performSearch(_ query: String, in document: PDFDocument?) {
        guard let doc = document else { return }

        // Cancel any in-flight search
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = trimmed
        guard !trimmed.isEmpty else { clearSearch(); return }

        isSearching = true
        loadingStateManager.startSearch("Searching in PDF...")

        searchTask = Task {
            let startTime = Date()
            // findString runs on the main actor (PDFKit is not thread-safe)
            // but wrapping in a Task yields to the run loop, keeping UI responsive
            let results = doc.findString(trimmed, withOptions: [.caseInsensitive])

            guard !Task.isCancelled else { return }

            results.forEach { $0.color = NSColor.systemOrange.withAlphaComponent(0.6) }
            searchResults = results
            searchIndex = 0
            focusCurrentSearchSelection(in: document)
            performanceMonitor.trackSearch(startTime)
            isSearching = false
            loadingStateManager.stopSearch()
        }
    }

    func nextSearchResult(in document: PDFDocument?) {
        guard !searchResults.isEmpty else { return }
        searchIndex = (searchIndex + 1) % searchResults.count
        focusCurrentSearchSelection(in: document)
    }

    func previousSearchResult(in document: PDFDocument?) {
        guard !searchResults.isEmpty else { return }
        searchIndex = (searchIndex - 1 + searchResults.count) % searchResults.count
        focusCurrentSearchSelection(in: document)
    }

    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchResults = []
        searchIndex = 0
        searchQuery = ""
        selectionBridge.setHighlightedSelections([])
    }

    func jumpToSearchResult(_ index: Int, in document: PDFDocument?) {
        guard !searchResults.isEmpty else { return }
        let count = searchResults.count
        let idx = ((index % count) + count) % count
        searchIndex = idx
        focusCurrentSearchSelection(in: document)
    }

    /// Focuses the current search selection and returns the page index if navigation is needed.
    @discardableResult
    func focusCurrentSearchSelection(in document: PDFDocument?) -> Int? {
        guard !searchResults.isEmpty, searchIndex >= 0, searchIndex < searchResults.count else { return nil }
        let sel = searchResults[searchIndex]
        selectionBridge.setHighlightedSelections(searchResults)
        var pageIndex: Int?
        if let page = sel.pages.first, let doc = document {
            let idx = doc.index(for: page)
            if idx >= 0 && idx < doc.pageCount { pageIndex = idx }
        }
        selectionBridge.pdfView?.go(to: sel)
        return pageIndex
    }

}
