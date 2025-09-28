import Foundation
import Combine
import PDFKit
import os.log

/// Scalable search system with text indexing for large PDFs
/// Replaces expensive PDFKit findString operations with pre-indexed text
@MainActor
class SearchIndexManager: ObservableObject {
    static let shared = SearchIndexManager()
    
    @Published var isIndexing: Bool = false
    @Published var indexingProgress: Double = 0.0
    @Published var indexedPages: Int = 0
    @Published var totalPages: Int = 0
    
    private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DevReader", category: "SearchIndex")
    private var searchIndices: [URL: PDFSearchIndex] = [:]
    private let indexQueue = DispatchQueue(label: "com.devreader.searchindex", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Search Index Structure
    
    struct PDFSearchIndex: Codable {
        let pdfURL: URL
        let createdDate: Date
        let pageCount: Int
        var pageTexts: [Int: String] // Page index -> extracted text
        var wordPositions: [String: [PageWordPosition]] // Word -> positions
        let version: String
        
        init(pdfURL: URL, createdDate: Date, pageCount: Int, pageTexts: [Int: String] = [:], wordPositions: [String: [PageWordPosition]] = [:]) {
            self.pdfURL = pdfURL
            self.createdDate = createdDate
            self.pageCount = pageCount
            self.pageTexts = pageTexts
            self.wordPositions = wordPositions
            self.version = "1.0"
        }
    }
    
    struct PageWordPosition: Codable {
        let pageIndex: Int
        let wordIndex: Int
        let range: NSRange
    }
    
    struct SearchOptions {
        let wholeWords: Bool
        let caseSensitive: Bool
        let maxResults: Int
        
        init(wholeWords: Bool = false, caseSensitive: Bool = false, maxResults: Int = 1000) {
            self.wholeWords = wholeWords
            self.caseSensitive = caseSensitive
            self.maxResults = maxResults
        }
    }
    
    // MARK: - Index Management
    
    /// Create or update search index for a PDF
    func indexPDF(_ pdfURL: URL, document: PDFDocument) async {
        guard !isIndexing else { return }
        
        isIndexing = true
        indexingProgress = 0.0
        totalPages = document.pageCount
        indexedPages = 0
        
        defer {
            isIndexing = false
            indexingProgress = 1.0
        }
        
        await withTaskGroup(of: Void.self) { group in
            // Index pages in parallel for better performance
            for pageIndex in 0..<document.pageCount {
                group.addTask {
                    await self.indexPage(document, pageIndex: pageIndex, pdfURL: pdfURL)
                }
            }
        }
        
        // Save index to disk
        await saveIndex(for: pdfURL)
        
        os_log("Search index created for PDF: %{public}@ (%d pages)", log: logger, type: .info, pdfURL.lastPathComponent, document.pageCount)
    }
    
    private func indexPage(_ document: PDFDocument, pageIndex: Int, pdfURL: URL) async {
        guard let page = document.page(at: pageIndex) else { return }
        
        // Extract text from page
        let pageText = page.string ?? ""
        
        // Create word positions
        let words = pageText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var wordPositions: [String: [PageWordPosition]] = [:]
        var currentPosition = 0
        
        for (wordIndex, word) in words.enumerated() {
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if !cleanWord.isEmpty {
                let range = NSRange(location: currentPosition, length: word.count)
                let position = PageWordPosition(pageIndex: pageIndex, wordIndex: wordIndex, range: range)
                
                if wordPositions[cleanWord] == nil {
                    wordPositions[cleanWord] = []
                }
                wordPositions[cleanWord]?.append(position)
            }
            currentPosition += word.count + 1 // +1 for space
        }
        
        // Update index on main thread
        await MainActor.run {
            if searchIndices[pdfURL] == nil {
                searchIndices[pdfURL] = PDFSearchIndex(
                    pdfURL: pdfURL,
                    createdDate: Date(),
                    pageCount: document.pageCount,
                    pageTexts: [:],
                    wordPositions: [:]
                )
            }
            
            searchIndices[pdfURL]?.pageTexts[pageIndex] = pageText
            searchIndices[pdfURL]?.wordPositions.merge(wordPositions) { existing, new in
                existing + new
            }
            
            indexedPages += 1
            indexingProgress = Double(indexedPages) / Double(totalPages)
        }
    }
    
    // MARK: - Search Operations
    
    /// Perform fast search using pre-indexed text
    func search(_ query: String, in pdfURL: URL, options: SearchOptions? = nil) -> [SearchResult] {
        let searchOptions = options ?? SearchOptions()
        guard let index = searchIndices[pdfURL] else {
            os_log("No search index found for PDF: %{public}@", log: logger, type: .error, pdfURL.lastPathComponent)
            return []
        }
        
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        
        if searchOptions.wholeWords {
            // Search for exact word matches
            if let positions = index.wordPositions[cleanQuery] {
                for position in positions {
                    let result = SearchResult(
                        pageIndex: position.pageIndex,
                        text: index.pageTexts[position.pageIndex] ?? "",
                        range: position.range,
                        context: getContext(for: position, in: index.pageTexts[position.pageIndex] ?? "")
                    )
                    results.append(result)
                }
            }
        } else {
            // Search for substring matches
            for (pageIndex, pageText) in index.pageTexts {
                let lowercasedText = pageText.lowercased()
                var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
                
                while let range = lowercasedText.range(of: cleanQuery, range: searchRange) {
                    let nsRange = NSRange(range, in: pageText)
                    let result = SearchResult(
                        pageIndex: pageIndex,
                        text: pageText,
                        range: nsRange,
                        context: getContext(for: nsRange, in: pageText)
                    )
                    results.append(result)
                    
                    // Move search range forward
                    searchRange = range.upperBound..<lowercasedText.endIndex
                }
            }
        }
        
        // Sort results by page index
        results.sort { $0.pageIndex < $1.pageIndex }
        
        os_log("Search completed: %d results for query '%{public}@'", log: logger, type: .info, results.count, query)
        return results
    }
    
    private func getContext(for range: NSRange, in text: String) -> String {
        let contextLength = 50
        let start = max(0, range.location - contextLength)
        let end = min(text.count, range.location + range.length + contextLength)
        
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        
        return String(text[startIndex..<endIndex])
    }
    
    private func getContext(for position: PageWordPosition, in text: String) -> String {
        let contextLength = 50
        let start = max(0, position.range.location - contextLength)
        let end = min(text.count, position.range.location + position.range.length + contextLength)
        
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        
        return String(text[startIndex..<endIndex])
    }
    
    // MARK: - Index Persistence
    
    private func saveIndex(for pdfURL: URL) async {
        guard let index = searchIndices[pdfURL] else { return }
        
        let indexURL = getIndexURL(for: pdfURL)
        
        do {
            let data = try JSONEncoder().encode(index)
            try data.write(to: indexURL)
            os_log("Search index saved: %{public}@", log: logger, type: .info, indexURL.path)
        } catch {
            os_log("Failed to save search index: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    func loadIndex(for pdfURL: URL) async {
        let indexURL = getIndexURL(for: pdfURL)
        
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: indexURL)
            let index = try JSONDecoder().decode(PDFSearchIndex.self, from: data)
            searchIndices[pdfURL] = index
            os_log("Search index loaded: %{public}@", log: logger, type: .info, indexURL.path)
        } catch {
            os_log("Failed to load search index: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    private func getIndexURL(for pdfURL: URL) -> URL {
        let hash = String(pdfURL.path.hashValue)
        return JSONStorageService.dataDirectory.appendingPathComponent("search_index_\(hash).json")
    }
    
    // MARK: - Index Management
    
    func clearIndex(for pdfURL: URL) {
        searchIndices.removeValue(forKey: pdfURL)
        
        let indexURL = getIndexURL(for: pdfURL)
        try? FileManager.default.removeItem(at: indexURL)
        
        os_log("Search index cleared: %{public}@", log: logger, type: .info, pdfURL.lastPathComponent)
    }
    
    func clearAllIndices() {
        searchIndices.removeAll()
        
        let dataDirectory = JSONStorageService.dataDirectory
        let indexFiles = (try? FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        
        for file in indexFiles where file.lastPathComponent.hasPrefix("search_index_") {
            try? FileManager.default.removeItem(at: file)
        }
        
        os_log("All search indices cleared", log: logger, type: .info)
    }
    
    // MARK: - Performance Monitoring
    
    func getIndexStats(for pdfURL: URL) -> IndexStats? {
        guard let index = searchIndices[pdfURL] else { return nil }
        
        return IndexStats(
            pageCount: index.pageCount,
            totalWords: index.wordPositions.values.flatMap { $0 }.count,
            uniqueWords: index.wordPositions.keys.count,
            indexSize: calculateIndexSize(index)
        )
    }
    
    private func calculateIndexSize(_ index: PDFSearchIndex) -> Int {
        do {
            let data = try JSONEncoder().encode(index)
            return data.count
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Types

struct SearchResult {
    let pageIndex: Int
    let text: String
    let range: NSRange
    let context: String
}

struct SearchOptions {
    let wholeWords: Bool
    let caseSensitive: Bool
    let maxResults: Int
    
    init(wholeWords: Bool = false, caseSensitive: Bool = false, maxResults: Int = 1000) {
        self.wholeWords = wholeWords
        self.caseSensitive = caseSensitive
        self.maxResults = maxResults
    }
}

struct IndexStats {
    let pageCount: Int
    let totalWords: Int
    let uniqueWords: Int
    let indexSize: Int
}
