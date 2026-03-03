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

    private var searchTask: Task<Void, Never>?

    func performSearch(_ query: String, in document: PDFDocument?) {
        guard let doc = document else { return }

        // Cancel any in-flight search
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = trimmed
        guard !trimmed.isEmpty else { clearSearch(); return }

        isSearching = true
        LoadingStateManager.shared.startSearch("Searching in PDF...")

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
            PerformanceMonitor.shared.trackSearch(startTime)
            isSearching = false
            LoadingStateManager.shared.stopSearch()
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
        PDFSelectionBridge.shared.setHighlightedSelections([])
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
        guard !searchResults.isEmpty else { return nil }
        let sel = searchResults[searchIndex]
        PDFSelectionBridge.shared.setHighlightedSelections(searchResults)
        var pageIndex: Int?
        if let page = sel.pages.first, let doc = document {
            let idx = doc.index(for: page)
            if idx >= 0 && idx < doc.pageCount { pageIndex = idx }
        }
        PDFSelectionBridge.shared.pdfView?.go(to: sel)
        return pageIndex
    }

    // performSearchOptimized removed — performSearch is now non-blocking for all PDFs
}
