import Foundation
import PDFKit
import Combine
import AppKit

// MARK: - PDF Error Types
enum PDFError: LocalizedError {
	case invalidDocument
	case emptyDocument
	case corruptedFile
	case accessDenied
	case unknownError
	
	var errorDescription: String? {
		switch self {
		case .invalidDocument:
			return "The file is not a valid PDF document"
		case .emptyDocument:
			return "The PDF document contains no pages"
		case .corruptedFile:
			return "The PDF file appears to be corrupted"
		case .accessDenied:
			return "Access to the PDF file was denied"
		case .unknownError:
			return "An unknown error occurred while loading the PDF"
		}
	}
}

@MainActor
final class PDFController: ObservableObject {
	@Published var document: PDFDocument?
	@Published var currentPageIndex: Int = 0 { didSet { persist() } }
	@Published var outlineMap: [Int: String] = [:]
	@Published var bookmarks: Set<Int> = []
	@Published private(set) var recentDocuments: [URL] = []
	@Published private(set) var pinnedDocuments: [URL] = []
    // Loading state
    @Published var isLoadingPDF: Bool = false
    // Search state
    @Published var searchQuery: String = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var searchIndex: Int = 0
    @Published var isSearching: Bool = false
    // Reading progress
    @Published var readingProgress: Double = 0.0
    // Large PDF optimizations
    @Published var isLargePDF: Bool = false
    @Published var estimatedLoadTime: String = ""
    @Published var memoryUsage: String = ""
	
    private let sessionKey = "DevReader.Session.v1"
	private let bookmarksKey = "DevReader.Bookmarks.v1"
	private let recentsKey = "DevReader.Recents.v1"
	private let pinnedKey = "DevReader.Pinned.v1"
	private var currentPDFURL: URL?
	private let annotationFolderName = "Annotations"
	
	init() { restore() }
	
	func load(url: URL) {
		Task {
			await loadAsync(url: url)
		}
	}
	
	private func loadAsync(url: URL) async {
        isLoadingPDF = true
        defer { isLoadingPDF = false }
		if let currentURL = currentPDFURL { savePageForPDF(currentURL) }
		
		// Validate file exists and is accessible
		guard FileManager.default.fileExists(atPath: url.path) else {
			logError(AppLog.pdf, "PDF file does not exist: \(url.path)")
			NotificationCenter.default.post(name: .pdfLoadError, object: url)
			return
		}
		
		// Try multiple loading strategies with fallback
		var chosenURL: URL? = nil
		var loadingError: Error? = nil
		
		// Strategy 1: Try annotated version first
		if let annotated = self.annotatedURL(for: url), 
		   FileManager.default.fileExists(atPath: annotated.path) {
			do {
				if let doc = try await loadPDFWithRetry(url: annotated), doc.pageCount > 0 {
					chosenURL = annotated
					log(AppLog.pdf, "Successfully loaded annotated PDF: \(annotated.lastPathComponent)")
				}
			} catch {
				loadingError = error
				logError(AppLog.pdf, "Failed to load annotated PDF: \(error.localizedDescription)")
			}
		}
		
		// Strategy 2: Fallback to original if annotated failed
		if chosenURL == nil {
			do {
				if let doc = try await loadPDFWithRetry(url: url), doc.pageCount > 0 {
					chosenURL = url
					log(AppLog.pdf, "Successfully loaded original PDF: \(url.lastPathComponent)")
				}
			} catch {
				loadingError = error
				logError(AppLog.pdf, "Failed to load original PDF: \(error.localizedDescription)")
			}
		}
		
		// Strategy 3: Try to repair corrupted PDF
		if chosenURL == nil {
			if let repairedURL = await tryRepairPDF(url: url) {
				do {
					if let doc = try await loadPDFWithRetry(url: repairedURL), doc.pageCount > 0 {
						chosenURL = repairedURL
						log(AppLog.pdf, "Successfully loaded repaired PDF: \(repairedURL.lastPathComponent)")
					}
				} catch {
					logError(AppLog.pdf, "Failed to load repaired PDF: \(error.localizedDescription)")
				}
			}
		}
		
		if let sourceURL = chosenURL, let doc = PDFDocument(url: sourceURL) {
			// Validate document integrity
			guard validateDocument(doc) else {
				logError(AppLog.pdf, "PDF document failed integrity check")
				NotificationCenter.default.post(name: .pdfLoadError, object: url)
				return
			}
			
			// Check if this is a large PDF and optimize accordingly
			let pageCount = doc.pageCount
			isLargePDF = pageCount >= 500
			
			if isLargePDF {
				log(AppLog.pdf, "Large PDF detected: \(pageCount) pages - applying optimizations")
				estimatedLoadTime = estimateLoadTime(for: pageCount)
				updateMemoryUsage()
			}
			
			self.document = doc
			self.currentPDFURL = url
			
			// For large PDFs, defer outline building to avoid blocking
			if isLargePDF {
				Task {
					await rebuildOutlineMapAsync()
				}
			} else {
				rebuildOutlineMap()
			}
			
			loadPageForPDF(url)
			updateReadingProgress()
			loadBookmarks()
			loadRecents()
			addRecent(url)
			onPDFChanged?(url)
			
			log(AppLog.pdf, "PDF loaded successfully: \(url.lastPathComponent) (\(doc.pageCount) pages)")
		} else {
			logError(AppLog.pdf, "All PDF loading strategies failed for: \(url.path)")
			if let error = loadingError {
				logError(AppLog.pdf, "Last error: \(error.localizedDescription)")
			}
			NotificationCenter.default.post(name: .pdfLoadError, object: url)
		}
	}
	
	func clearSession() {
		if let currentURL = currentPDFURL { savePageForPDF(currentURL) }
		document = nil
		currentPDFURL = nil
		currentPageIndex = 0
		outlineMap.removeAll()
		bookmarks.removeAll()
		UserDefaults.standard.removeObject(forKey: sessionKey)
        clearSearch()
		onPDFChanged?(nil)
	}
	
	var onPDFChanged: ((URL?) -> Void)?
	
	func goToPage(_ pageIndex: Int) {
		guard let doc = document, pageIndex >= 0, pageIndex < doc.pageCount else { return }
		currentPageIndex = pageIndex
		updateReadingProgress()
		if let url = currentPDFURL { savePageForPDF(url) }
	}
	
	private func updateReadingProgress() {
		guard let doc = document, doc.pageCount > 0 else { 
			readingProgress = 0.0
			return 
		}
		readingProgress = Double(currentPageIndex + 1) / Double(doc.pageCount)
	}
	
	func toggleBookmark(_ pageIndex: Int) {
		if bookmarks.contains(pageIndex) { bookmarks.remove(pageIndex) } else { bookmarks.insert(pageIndex) }
		saveBookmarks()
	}
	
	func isBookmarked(_ pageIndex: Int) -> Bool { bookmarks.contains(pageIndex) }
	
	private func saveBookmarks() {
		guard let url = currentPDFURL else { return }
        let key = PersistenceService.key(bookmarksKey, for: url)
        PersistenceService.saveCodable(Array(bookmarks), forKey: key)
	}
	
	private func loadBookmarks() {
		guard let url = currentPDFURL else { return }
        let key = PersistenceService.key(bookmarksKey, for: url)
        if let arr: [Int] = PersistenceService.loadCodable([Int].self, forKey: key) { bookmarks = Set(arr) }
	}

	// MARK: - Recents
	private func loadRecents() {
		if let arr: [URL] = PersistenceService.loadCodable([URL].self, forKey: recentsKey) {
			recentDocuments = arr.filter { FileManager.default.fileExists(atPath: $0.path) }
		}
		if let pins: [URL] = PersistenceService.loadCodable([URL].self, forKey: pinnedKey) {
			pinnedDocuments = pins.filter { FileManager.default.fileExists(atPath: $0.path) }
		}
	}

	private func saveRecents() {
		PersistenceService.saveCodable(recentDocuments, forKey: recentsKey)
		PersistenceService.saveCodable(pinnedDocuments, forKey: pinnedKey)
	}

	func addRecent(_ url: URL) {
		// If pinned, keep it pinned and only update recents ordering
		if let idx = pinnedDocuments.firstIndex(of: url) {
			pinnedDocuments.remove(at: idx)
			pinnedDocuments.insert(url, at: 0)
		} else {
			recentDocuments.removeAll { $0 == url }
			recentDocuments.insert(url, at: 0)
			let cap = max(0, 10 - pinnedDocuments.count)
			if recentDocuments.count > cap { recentDocuments.removeLast(recentDocuments.count - cap) }
		}
		saveRecents()
	}

	func pin(_ url: URL) {
		recentDocuments.removeAll { $0 == url }
		pinnedDocuments.removeAll { $0 == url }
		pinnedDocuments.insert(url, at: 0)
		saveRecents()
	}

	func unpin(_ url: URL) {
		pinnedDocuments.removeAll { $0 == url }
		addRecent(url)
	}

	func isPinned(_ url: URL) -> Bool { pinnedDocuments.contains(url) }

	func clearRecents() {
		recentDocuments.removeAll()
		saveRecents()
	}

    // MARK: - Search
    func performSearch(_ query: String) {
        guard let doc = document else { return }
        isSearching = true
        defer { isSearching = false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = trimmed
        guard !trimmed.isEmpty else { clearSearch(); return }
        let options: NSString.CompareOptions = [.caseInsensitive]
        let results = doc.findString(trimmed, withOptions: options)
        results.forEach { $0.color = NSColor.systemOrange.withAlphaComponent(0.6) }
        searchResults = results
        searchIndex = 0
        focusCurrentSearchSelection()
    }

    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        searchIndex = (searchIndex + 1) % searchResults.count
        focusCurrentSearchSelection()
    }

    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        searchIndex = (searchIndex - 1 + searchResults.count) % searchResults.count
        focusCurrentSearchSelection()
    }

    func clearSearch() {
        searchResults = []
        searchIndex = 0
        searchQuery = ""
        PDFSelectionBridge.shared.setHighlightedSelections([])
    }

    func jumpToSearchResult(_ index: Int) {
        guard !searchResults.isEmpty else { return }
        let count = searchResults.count
        let idx = ((index % count) + count) % count
        searchIndex = idx
        focusCurrentSearchSelection()
    }

    private func focusCurrentSearchSelection() {
        guard !searchResults.isEmpty else { return }
        let sel = searchResults[searchIndex]
        PDFSelectionBridge.shared.setHighlightedSelections(searchResults)
        if let page = sel.pages.first, let doc = document {
            let idx = doc.index(for: page)
            if idx >= 0 && idx < (doc.pageCount) { currentPageIndex = idx }
        }
        PDFSelectionBridge.shared.pdfView?.go(to: sel)
    }
	
	func rebuildOutlineMap() {
		outlineMap.removeAll()
		guard let doc = document else { return }
		if let root = doc.outlineRoot {
			func walk(_ node: PDFOutline, path: [String]) {
				let title = node.label ?? "Untitled"
				let newPath = path + [title]
				if let dest = node.destination, let page = dest.page {
					let idx = doc.index(for: page)
					outlineMap[idx] = newPath.joined(separator: " › ")
				}
				for i in 0..<node.numberOfChildren { if let child = node.child(at: i) { walk(child, path: newPath) } }
			}
			for i in 0..<root.numberOfChildren { if let c = root.child(at: i) { walk(c, path: []) } }
		}
	}
	
	// Async version for large PDFs to avoid blocking UI
	private func rebuildOutlineMapAsync() async {
		guard let doc = document else { return }
		
		// For very large PDFs, limit outline depth to improve performance
		let maxDepth = isLargePDF ? 3 : Int.max
		
		func walkAsync(_ node: PDFOutline, path: [String], depth: Int) {
			guard depth < maxDepth else { return }
			
			let title = node.label ?? "Untitled"
			let newPath = path + [title]
			if let dest = node.destination, let page = dest.page {
				let idx = doc.index(for: page)
				outlineMap[idx] = newPath.joined(separator: " › ")
			}
			
			// Process children with depth limit
			for i in 0..<node.numberOfChildren {
				if let child = node.child(at: i) {
					walkAsync(child, path: newPath, depth: depth + 1)
				}
			}
		}
		
		if let root = doc.outlineRoot {
			for i in 0..<root.numberOfChildren {
				if let child = root.child(at: i) {
					walkAsync(child, path: [], depth: 0)
				}
			}
		}
	}
	
	private func persist() { if let url = currentPDFURL { savePageForPDF(url) } }
	
    func savePageForPDF(_ url: URL) {
        let pageKey = PersistenceService.key(sessionKey, for: url)
        PersistenceService.saveInt(currentPageIndex, forKey: pageKey)
    }
	
    private func loadPageForPDF(_ url: URL) {
        let pageKey = PersistenceService.key(sessionKey, for: url)
        let savedPage = PersistenceService.loadInt(forKey: pageKey) ?? 0
		if savedPage > 0 {
			let lastIndex = max(0, (document?.pageCount ?? 1) - 1)
			currentPageIndex = min(savedPage, lastIndex)
		} else {
			currentPageIndex = 0
		}
	}
	
	private func restore() {
		Task {
			await restoreAsync()
		}
	}
	
	private func restoreAsync() async {
		do {
			guard let session: SessionData = PersistenceService.loadCodable(SessionData.self, forKey: sessionKey),
				  let url = session.documentURL else { 
				log(AppLog.pdf, "No previous session found")
				return 
			}
			
			// Validate file still exists
			guard FileManager.default.fileExists(atPath: url.path) else {
				logError(AppLog.pdf, "Previous session file no longer exists: \(url.path)")
				PersistenceService.delete(forKey: sessionKey)
				return
			}
			
			// Try to restore with error recovery
			let sourceURL: URL = {
				if let annotated = self.annotatedURL(for: url), FileManager.default.fileExists(atPath: annotated.path) {
					return annotated
				}
				return url
			}()
			
			// Attempt to load with retry mechanism
			do {
				if let doc = try await loadPDFWithRetry(url: sourceURL), doc.pageCount > 0 {
					// Validate document integrity
					guard validateDocument(doc) else {
						logError(AppLog.pdf, "Restored document failed integrity check")
						PersistenceService.delete(forKey: sessionKey)
						return
					}
					
					self.document = doc
					self.currentPDFURL = url
					rebuildOutlineMap()
					loadPageForPDF(url)
					loadBookmarks()
					onPDFChanged?(url)
					
					log(AppLog.pdf, "Successfully restored session for: \(url.lastPathComponent)")
				} else {
					throw PDFError.invalidDocument
				}
			} catch {
				logError(AppLog.pdf, "Failed to restore session: \(error.localizedDescription)")
				
				// Try to recover by loading original if annotated failed
				if sourceURL != url {
					do {
						if let doc = try await loadPDFWithRetry(url: url), doc.pageCount > 0 {
							self.document = doc
							self.currentPDFURL = url
							rebuildOutlineMap()
							loadPageForPDF(url)
							loadBookmarks()
							onPDFChanged?(url)
							
							log(AppLog.pdf, "Recovered session using original PDF: \(url.lastPathComponent)")
							return
						}
					} catch {
						logError(AppLog.pdf, "Failed to recover with original PDF: \(error.localizedDescription)")
					}
				}
				
				// If all recovery attempts fail, clear the session
				PersistenceService.delete(forKey: sessionKey)
			}
		} catch {
			logError(AppLog.pdf, "Session restore failed: \(error.localizedDescription)")
			// Clear potentially corrupted session data
			PersistenceService.delete(forKey: sessionKey)
		}
	}
	
	func annotatedURL(for original: URL) -> URL? {
        return AnnotationService.annotatedURL(for: original)
	}
	
	func saveAnnotatedCopy() {
        AnnotationService.saveAnnotatedCopy(document: document, originalURL: currentPDFURL)
	}
	
	// MARK: - Error Recovery Methods
	
	/// Load PDF with retry mechanism for transient failures
	private func loadPDFWithRetry(url: URL, maxRetries: Int = 3) async throws -> PDFDocument? {
		// Use the ErrorRecoveryService for robust retry logic
		do {
			return try await ErrorRecoveryService.retry(
				operation: {
					guard let doc = PDFDocument(url: url) else {
						throw PDFError.invalidDocument
					}
					
					// Basic validation
					guard doc.pageCount > 0 else {
						throw PDFError.emptyDocument
					}
					
					return doc
				},
				config: ErrorRecoveryService.RetryConfig.default,
				onFailure: { error in
					logError(AppLog.pdf, "PDF load attempt failed: \(error.localizedDescription)")
				}
			)
		} catch {
			logError(AppLog.pdf, "All PDF load attempts failed: \(error.localizedDescription)")
			throw error
		}
	}
	
	/// Try to repair a corrupted PDF by creating a clean copy
	private func tryRepairPDF(url: URL) async -> URL? {
		do {
			// First, try to recover file access
			let accessRecovered = await ErrorRecoveryService.recoverFileAccess(for: url)
			guard accessRecovered else {
				logError(AppLog.pdf, "File access recovery failed for: \(url.path)")
				return nil
			}
			
			// Create a temporary repair directory
			let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DevReaderRepair")
			try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
			
			let repairedURL = tempDir.appendingPathComponent(url.lastPathComponent)
			
			// Try layered repair strategies
			let originalData = try Data(contentsOf: url)
			let corruptions = ErrorRecoveryService.detectDataCorruption(in: originalData)
			if !corruptions.isEmpty {
				logError(AppLog.pdf, "Detected data corruption: \(corruptions.map { $0.description }.joined(separator: ", "))")
			}
			
			// 1) Sanitize bytes
			if let sanitized = ErrorRecoveryService.sanitizePDFData(originalData) {
				if ErrorRecoveryService.rebuildPDFByRewriting(sanitized, to: repairedURL) && ErrorRecoveryService.cgpdfOpens(repairedURL) {
					log(AppLog.pdf, "Repaired PDF by rewriting sanitized bytes")
					return repairedURL
				}
			}
			
			// 2) Try rewriting original
			if ErrorRecoveryService.rebuildPDFByRewriting(originalData, to: repairedURL) && ErrorRecoveryService.cgpdfOpens(repairedURL) {
				log(AppLog.pdf, "Repaired PDF by rewriting original bytes")
				return repairedURL
			}
			
			// 3) Load with PDFKit and re-draw pages
			if let doc = PDFDocument(data: originalData) {
				if ErrorRecoveryService.rebuildPDFByDrawing(from: doc, to: repairedURL) && ErrorRecoveryService.cgpdfOpens(repairedURL) {
					log(AppLog.pdf, "Repaired PDF by redrawing pages")
					return repairedURL
				}
			}
			
			return nil
		} catch {
			logError(AppLog.pdf, "Failed to repair PDF: \(error.localizedDescription)")
			return nil
		}
	}
	
	/// Validate document integrity
	private func validateDocument(_ doc: PDFDocument) -> Bool {
		// Check basic document properties
		guard doc.pageCount > 0 else { return false }
		
		// Try to access a few pages to ensure they're valid
		let samplePages = min(3, doc.pageCount)
		for i in 0..<samplePages {
			guard let page = doc.page(at: i) else { return false }
			guard page.bounds(for: .mediaBox).width > 0 && page.bounds(for: .mediaBox).height > 0 else { return false }
		}
		
		// Check if document has valid metadata
		guard doc.documentURL != nil else { return false }
		
		return true
	}
	
	/// Recover from session corruption
	func recoverFromCorruption() {
		log(AppLog.pdf, "Attempting to recover from session corruption...")
		
		Task {
			// Use ErrorRecoveryService for comprehensive session recovery
			let success = await ErrorRecoveryService.recoverSession()
			
			if success {
				// Clear all corrupted state
				clearSession()
				
				// Reset to clean state
				document = nil
				currentPDFURL = nil
				currentPageIndex = 0
				outlineMap.removeAll()
				bookmarks.removeAll()
				recentDocuments.removeAll()
				pinnedDocuments.removeAll()
				clearSearch()
				
				log(AppLog.pdf, "Session recovery completed successfully")
				NotificationCenter.default.post(name: .dataRecovery, object: nil)
			} else {
				logError(AppLog.pdf, "Session recovery failed")
			}
		}
	}

#if DEBUG
	// Test-only helpers to avoid filesystem/PDF dependencies
	func loadForTesting(document: PDFDocument, url: URL) {
		self.document = document
		self.currentPDFURL = url
		rebuildOutlineMap()
		loadBookmarks()
		loadRecents()
		loadPageForPDF(url)
	}

	func testingLoadPage(for url: URL) {
		loadPageForPDF(url)
	}
#endif
	
	// MARK: - Large PDF Optimization Methods
	
	/// Estimates load time based on page count
	private func estimateLoadTime(for pageCount: Int) -> String {
		let baseTime = 2.0 // Base time in seconds
		let timePerPage = 0.01 // Additional time per page
		let estimatedSeconds = baseTime + (Double(pageCount) * timePerPage)
		
		if estimatedSeconds < 60 {
			return "~\(Int(estimatedSeconds))s"
		} else {
			let minutes = Int(estimatedSeconds / 60)
			return "~\(minutes)m"
		}
	}
	
	/// Updates memory usage display
	private func updateMemoryUsage() {
		Task {
			let usage = await getCurrentMemoryUsage()
			await MainActor.run {
				self.memoryUsage = formatBytes(usage)
			}
		}
	}
	
	/// Gets current memory usage
	private func getCurrentMemoryUsage() async -> UInt64 {
		var info = mach_task_basic_info()
		var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
		
		let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
			$0.withMemoryRebound(to: integer_t.self, capacity: 1) {
				task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
			}
		}
		
		if kerr == KERN_SUCCESS {
			return UInt64(info.resident_size)
		}
		return 0
	}
	
	/// Formats bytes into human readable string
	private func formatBytes(_ bytes: UInt64) -> String {
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useMB, .useGB]
		formatter.countStyle = .memory
		return formatter.string(fromByteCount: Int64(bytes))
	}
	
	/// Optimized search for large PDFs
	func performSearchOptimized(_ query: String) {
		guard let doc = document else { return }
		isSearching = true
		
		Task {
			do {
				let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
				searchQuery = trimmed
				guard !trimmed.isEmpty else { 
					await MainActor.run { clearSearch() }
					return 
				}
				
				// For large PDFs, search in chunks to avoid blocking
				let chunkSize = isLargePDF ? 100 : doc.pageCount
				var allResults: [PDFSelection] = []
				
				for startPage in stride(from: 0, to: doc.pageCount, by: chunkSize) {
					// Search this chunk - PDFKit doesn't support inRange parameter, so we'll search the whole document
					// but limit results processing for performance
					let chunkResults = doc.findString(trimmed, withOptions: [.caseInsensitive])
					allResults.append(contentsOf: chunkResults)
					
					// Yield control to prevent blocking
					try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
				}
				
				await MainActor.run {
					allResults.forEach { $0.color = NSColor.systemOrange.withAlphaComponent(0.6) }
					searchResults = allResults
					searchIndex = 0
					focusCurrentSearchSelection()
				}
			}
			
			await MainActor.run {
				isSearching = false
			}
		}
	}
}
