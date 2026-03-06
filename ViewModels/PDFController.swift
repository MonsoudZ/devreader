import Foundation
@preconcurrency import PDFKit
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
	@Published var currentPageIndex: Int = 0
	@Published private(set) var currentPDFURL: URL?
    // Loading state (not @Published — views use loadingStateManager; kept for tests)
    var isLoadingPDF: Bool = false
    // Reading progress (not @Published — only used internally/tests, avoids needless redraws)
    var readingProgress: Double = 0.0
    // Large PDF optimizations
    var isLargePDF: Bool = false
    var estimatedLoadTime: String = ""
    var memoryUsage: String = ""

	// MARK: - Event Publishers (replace NotificationCenter posts)
	let pdfLoadErrorPublisher = PassthroughSubject<URL, Never>()
	let noteRequestPublisher = PassthroughSubject<NoteItem, Never>()
	let toastRequestPublisher = PassthroughSubject<ToastMessage, Never>()

	// MARK: - Managers
	let selectionBridge = PDFSelectionBridge()
	let searchManager: PDFSearchManager
	let bookmarkManager = PDFBookmarkManager()
	let outlineManager = PDFOutlineManager()
	private(set) lazy var annotationManager = PDFAnnotationManager(pdfController: self)

    // MARK: - Constants
    private static let largePDFPageThreshold = 500
    private static let validationSamplePages = 3
    private static let loadDebounceNanoseconds: UInt64 = 100_000_000  // 0.1s
    private static let persistPageDelay: TimeInterval = 0.5
    private static let memoryPressureCooldown: TimeInterval = 5.0
    private static let loadEstimateBaseTime: TimeInterval = 2.0
    private static let loadEstimatePerPage: TimeInterval = 0.01
    private static let loadEstimateMinuteThreshold: TimeInterval = 60

    let loadingStateManager: LoadingStateManager
    let performanceMonitor: PerformanceMonitor

    private var activeSecurityScope: URL?
    private let sessionKey = "DevReader.Session.v1"
	private var loadingTask: Task<Void, Never>?
	private var outlineTask: Task<Void, Never>?
	private var isHandlingMemoryPressure = false
	nonisolated(unsafe) private var memoryPressureObserver: Any?
	private var pagePersister: DebouncedPersister?
	private var isRestoringPage = false
	private let lastOpenedPDFKey = "DevReader.LastOpenedPDF.v1"
	init(loadingStateManager: LoadingStateManager = .shared, performanceMonitor: PerformanceMonitor = .shared) {
		self.loadingStateManager = loadingStateManager
		self.performanceMonitor = performanceMonitor
		self.searchManager = PDFSearchManager(selectionBridge: selectionBridge, loadingStateManager: loadingStateManager, performanceMonitor: performanceMonitor)

		setupMemoryPressureHandler()
	}

	deinit {
		// removeObserver and cancel are thread-safe — safe from nonisolated deinit
		if let observer = memoryPressureObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		loadingTask?.cancel()
		outlineTask?.cancel()
	}

	func load(url: URL) {
		loadingTask?.cancel()
		loadingTask = Task {
			try? await Task.sleep(nanoseconds: Self.loadDebounceNanoseconds)
			guard !Task.isCancelled else { return }
			await loadAsync(url: url)
		}
	}

	/// Convenience alias used by ContentView
	func open(url: URL) {
		load(url: url)
	}

	/// Open a PDF from a library item, using its security-scoped bookmark if available.
	func load(libraryItem: LibraryItem) {
		if let resolved = libraryItem.resolveURLFromBookmark(),
		   FileManager.default.fileExists(atPath: resolved.path) {
			let didStart = resolved.startAccessingSecurityScopedResource()
			if didStart { activeSecurityScope = resolved }
			load(url: resolved)
			return
		}
		load(url: libraryItem.url)
	}

	/// Called after async load to release security scope if load failed.
	private func releaseSecurityScopeIfNeeded() {
		if document == nil, let scope = activeSecurityScope {
			scope.stopAccessingSecurityScopedResource()
			activeSecurityScope = nil
		}
	}

	private func cleanupCurrentPDF() async {
		annotationManager.flushPendingPersistence()
		if let scope = activeSecurityScope {
			scope.stopAccessingSecurityScopedResource()
			activeSecurityScope = nil
		}
		document = nil
		currentPDFURL = nil
		currentPageIndex = 0
		readingProgress = 0.0
		searchManager.clearSearch()
		outlineManager.clear()
		loadingTask?.cancel()
		loadingTask = nil
		outlineTask?.cancel()
		outlineTask = nil
	}

	private func loadAsync(url: URL) async {
        // Allow reload of same URL (e.g. after partial failure)
        if currentPDFURL == url && document != nil {
            return
        }
        flushPendingPersistence()
        await cleanupCurrentPDF()

        let startTime = Date()
        performanceMonitor.trackPDFLoad(startTime)

        loadingStateManager.startPDFLoading("Loading PDF...")
        isLoadingPDF = true
        defer {
            isLoadingPDF = false
            loadingStateManager.stopPDFLoading()
        }

		guard FileManager.default.fileExists(atPath: url.path) else {
			logError(AppLog.pdf, "PDF file does not exist: \(url.path)")
			pdfLoadErrorPublisher.send(url)
			releaseSecurityScopeIfNeeded()
			return
		}

		// Load the PDF document once and keep it
		var doc: PDFDocument?

		// Strategy 1: Load directly (fast path for normal PDFs)
		doc = await loadPDFOffMainThread(url: url)

		// Strategy 2: Try repair only if direct load failed
		if doc == nil {
			log(AppLog.pdf, "Direct load failed, attempting repair for: \(url.lastPathComponent)")
			if let repairedURL = await tryRepairPDF(url: url) {
				doc = await loadPDFOffMainThread(url: repairedURL)
			}
		}

		guard let loadedDoc = doc else {
			logError(AppLog.pdf, "All PDF loading strategies failed for: \(url.path)")
			pdfLoadErrorPublisher.send(url)
			releaseSecurityScopeIfNeeded()
			return
		}

		guard validateDocument(loadedDoc) else {
			logError(AppLog.pdf, "PDF document failed integrity check")
			pdfLoadErrorPublisher.send(url)
			releaseSecurityScopeIfNeeded()
			return
		}

		let pageCount = loadedDoc.pageCount
		isLargePDF = pageCount >= Self.largePDFPageThreshold

		if isLargePDF {
			estimatedLoadTime = estimateLoadTime(for: pageCount)
			updateMemoryUsage()
			loadingStateManager.updatePDFProgress(0.5, message: "Processing large PDF (\(pageCount) pages)...")
		}

		self.document = loadedDoc
		self.currentPDFURL = url

		do {
			try PersistenceService.saveCodable(url, forKey: lastOpenedPDFKey)
		} catch {
			logError(AppLog.persistence, "Failed to save last-opened PDF: \(error.localizedDescription)")
		}

		if isLargePDF {
			loadingStateManager.updatePDFProgress(0.8, message: "Building outline for large PDF...")
			outlineTask = Task {
				await outlineManager.rebuildOutlineMapAsync(from: document, isLargePDF: isLargePDF)
			}
		} else {
			outlineManager.rebuildOutlineMap(from: document)
		}

		loadPageForPDF(url)
		updateReadingProgress()
		bookmarkManager.loadBookmarks(for: currentPDFURL)
		annotationManager.restoreAnnotations(for: url)
		bookmarkManager.loadRecents()
		bookmarkManager.addRecent(url)
		onPDFChanged?(url)

		log(AppLog.pdf, "PDF loaded successfully: \(url.lastPathComponent) (\(loadedDoc.pageCount) pages)")
	}

	/// Loads a PDFDocument off the main thread, returning nil on failure.
	private func loadPDFOffMainThread(url: URL) async -> PDFDocument? {
		await Task.detached(priority: .userInitiated) {
			guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
				return nil
			}
			return doc
		}.value
	}

	func clearSession() {
		flushPendingPersistence()
		annotationManager.flushPendingPersistence()
		annotationManager.clearAnnotations()
		document = nil
		currentPDFURL = nil
		currentPageIndex = 0
		outlineManager.clear()
		bookmarkManager.bookmarks.removeAll()
		UserDefaults.standard.removeObject(forKey: sessionKey)
		searchManager.clearSearch()
		PersistenceService.delete(forKey: lastOpenedPDFKey)
		onPDFChanged?(nil)
	}

	var onPDFChanged: ((URL?) -> Void)?

	func goToPage(_ pageIndex: Int) {
		guard let doc = document, pageIndex >= 0, pageIndex < doc.pageCount else { return }
		currentPageIndex = pageIndex
		updateReadingProgress()
		schedulePersistPage()
	}

	func updateReadingProgress() {
		guard let doc = document, doc.pageCount > 0 else {
			readingProgress = 0.0
			return
		}
		readingProgress = Double(currentPageIndex + 1) / Double(doc.pageCount)
	}

	// MARK: - Print

	func printDocument() {
		guard let pdfView = selectionBridge.pdfView, pdfView.document != nil else { return }
		pdfView.print(with: .shared, autoRotate: true, pageScaling: .pageScaleToFit)
	}

	// MARK: - Zoom

	@Published var scaleFactor: CGFloat = 1.0

	func zoomIn() {
		guard let pdfView = selectionBridge.pdfView else { return }
		let newScale = min(pdfView.scaleFactor * 1.25, pdfView.maxScaleFactor)
		pdfView.scaleFactor = newScale
		scaleFactor = newScale
	}

	func zoomOut() {
		guard let pdfView = selectionBridge.pdfView else { return }
		let newScale = max(pdfView.scaleFactor / 1.25, pdfView.minScaleFactor)
		pdfView.scaleFactor = newScale
		scaleFactor = newScale
	}

	func zoomToFit() {
		guard let pdfView = selectionBridge.pdfView else { return }
		pdfView.autoScales = true
		// Read back the computed scale after autoScales applies
		DispatchQueue.main.async { [weak self] in
			guard let self, let pv = self.selectionBridge.pdfView else { return }
			self.scaleFactor = pv.scaleFactor
			pv.autoScales = false
		}
	}

	func zoomActualSize() {
		guard let pdfView = selectionBridge.pdfView else { return }
		pdfView.scaleFactor = 1.0
		pdfView.autoScales = false
		scaleFactor = 1.0
	}

	func syncScaleFactor() {
		if let pdfView = selectionBridge.pdfView {
			scaleFactor = pdfView.scaleFactor
		}
	}

	// MARK: - Page Navigation

	func goToFirstPage() {
		goToPage(0)
	}

	func goToLastPage() {
		guard let doc = document else { return }
		goToPage(doc.pageCount - 1)
	}

	func goToNextPage() {
		guard let doc = document, currentPageIndex < doc.pageCount - 1 else { return }
		goToPage(currentPageIndex + 1)
	}

	func goToPreviousPage() {
		guard currentPageIndex > 0 else { return }
		goToPage(currentPageIndex - 1)
	}

	// MARK: - Display Mode

	@Published var displayMode: PDFDisplayMode = .singlePageContinuous

	func setDisplayMode(_ mode: PDFDisplayMode) {
		guard let pdfView = selectionBridge.pdfView else { return }
		pdfView.displayMode = mode
		displayMode = mode
	}

	// MARK: - Debounced Page Persistence

	func didScrollToPage(_ index: Int) {
		guard let doc = document, index >= 0, index < doc.pageCount else { return }
		currentPageIndex = index
		updateReadingProgress()
		schedulePersistPage()
	}

	private func schedulePersistPage() {
		guard !isRestoringPage else { return }
		if pagePersister == nil {
			pagePersister = DebouncedPersister(delay: Self.persistPageDelay) { [weak self] in
				guard let self, let url = self.currentPDFURL else { return }
				self.savePageForPDF(url)
			}
		}
		pagePersister?.schedule()
	}

	func flushPendingPersistence() {
		pagePersister?.flush()
	}

    func savePageForPDF(_ url: URL) {
        let pageKey = PersistenceService.key(sessionKey, for: url)
        do {
            try PersistenceService.saveInt(currentPageIndex, forKey: pageKey)
        } catch {
            logError(AppLog.persistence, "Failed to save page position: \(error.localizedDescription)")
        }
    }

    private func loadPageForPDF(_ url: URL) {
		isRestoringPage = true
		defer { isRestoringPage = false }
        let pageKey = PersistenceService.key(sessionKey, for: url)
        let legacyPageKey = PersistenceService.legacyKey(sessionKey, for: url)
        let savedPage = PersistenceService.loadCodableWithMigration(Int.self, forKey: pageKey, legacyKey: legacyPageKey) ?? 0
		if savedPage > 0 {
			let lastIndex = max(0, (document?.pageCount ?? 1) - 1)
			currentPageIndex = min(savedPage, lastIndex)
		} else {
			currentPageIndex = 0
		}
		updateReadingProgress()
	}

	private func setupMemoryPressureHandler() {
		memoryPressureObserver = NotificationCenter.default.addObserver(
			forName: .memoryPressure,
			object: nil,
			queue: .main
		) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in
				self.handleMemoryPressure()
			}
		}
	}

	@MainActor
	private func handleMemoryPressure() {
		guard !isHandlingMemoryPressure else { return }
		isHandlingMemoryPressure = true
		logError(AppLog.pdf, "Critical memory pressure - clearing caches")
		URLCache.shared.removeAllCachedResponses()
		DispatchQueue.main.asyncAfter(deadline: .now() + Self.memoryPressureCooldown) { [weak self] in
			self?.isHandlingMemoryPressure = false
		}
	}

	// MARK: - PDF Repair

	private func tryRepairPDF(url: URL) async -> URL? {
		do {
			let accessRecovered = await ErrorRecoveryService.recoverFileAccess(for: url)
			guard accessRecovered else {
				logError(AppLog.pdf, "File access recovery failed for: \(url.path)")
				return nil
			}

			let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DevReaderRepair")
			try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
			let repairedURL = tempDir.appendingPathComponent(url.lastPathComponent)

			let originalData = try Data(contentsOf: url)
			let corruptions = ErrorRecoveryService.detectDataCorruption(in: originalData)
			if !corruptions.isEmpty {
				logError(AppLog.pdf, "Detected data corruption: \(corruptions.map { $0.description }.joined(separator: ", "))")
			}

			if let sanitized = ErrorRecoveryService.sanitizePDFData(originalData) {
				if ErrorRecoveryService.rebuildPDFByRewriting(sanitized, to: repairedURL) && ErrorRecoveryService.cgpdfOpens(repairedURL) {
					log(AppLog.pdf, "Repaired PDF by rewriting sanitized bytes")
					return repairedURL
				}
			}

			if ErrorRecoveryService.rebuildPDFByRewriting(originalData, to: repairedURL) && ErrorRecoveryService.cgpdfOpens(repairedURL) {
				log(AppLog.pdf, "Repaired PDF by rewriting original bytes")
				return repairedURL
			}

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

	private func validateDocument(_ doc: PDFDocument) -> Bool {
		guard doc.pageCount > 0 else { return false }
		let samplePages = min(Self.validationSamplePages, doc.pageCount)
		for i in 0..<samplePages {
			guard let page = doc.page(at: i) else { return false }
			guard page.bounds(for: .mediaBox).width > 0 && page.bounds(for: .mediaBox).height > 0 else { return false }
		}
		return true
	}

	func recoverFromCorruption() {
		log(AppLog.pdf, "Attempting to recover from session corruption...")
		Task {
			let success = await ErrorRecoveryService.resetCorruptedState()
			if success {
				clearSession()
				document = nil
				currentPDFURL = nil
				currentPageIndex = 0
				outlineManager.clear()
				bookmarkManager.resetAll()
				searchManager.clearSearch()
				log(AppLog.pdf, "Session recovery completed successfully")
				NotificationCenter.default.post(name: .dataRecovery, object: nil)
			} else {
				logError(AppLog.pdf, "Session recovery failed")
			}
		}
	}

	// MARK: - State Restoration

	func restoreLastOpenedPDF() {
		guard let url: URL = PersistenceService.loadCodable(URL.self, forKey: lastOpenedPDFKey),
			  FileManager.default.fileExists(atPath: url.path) else { return }
		load(url: url)
	}

#if DEBUG
	func loadForTesting(document: PDFDocument, url: URL) {
		self.document = document
		self.currentPDFURL = url
		outlineManager.rebuildOutlineMap(from: document)
		bookmarkManager.loadBookmarks(for: url)
		bookmarkManager.loadRecents()
		loadPageForPDF(url)
	}

	func testingLoadPage(for url: URL) {
		loadPageForPDF(url)
	}
#endif

	// MARK: - Large PDF Optimization Methods

	private func estimateLoadTime(for pageCount: Int) -> String {
		let estimatedSeconds = Self.loadEstimateBaseTime + (Double(pageCount) * Self.loadEstimatePerPage)
		if estimatedSeconds < Self.loadEstimateMinuteThreshold {
			return "~\(Int(estimatedSeconds))s"
		} else {
			let minutes = Int(estimatedSeconds / 60)
			return "~\(minutes)m"
		}
	}

	private func updateMemoryUsage() {
		let monitor = performanceMonitor
		memoryUsage = monitor.formatBytes(monitor.memoryUsage)
	}

	// MARK: - PDF Annotation Layer (forwarding to annotationManager)

	func highlightSelection() { annotationManager.highlightSelection() }
	func underlineSelection() { annotationManager.underlineSelection() }
	func strikethroughSelection() { annotationManager.strikethroughSelection() }
	func captureHighlightToNotes() { annotationManager.captureHighlightToNotes() }
	func addStickyNote() { annotationManager.addStickyNote() }
	func exportAnnotatedPDF() { annotationManager.exportAnnotatedPDF() }
}
