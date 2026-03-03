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
    // Loading state
    @Published var isLoadingPDF: Bool = false
    // Reading progress
    @Published var readingProgress: Double = 0.0
    // Large PDF optimizations
    @Published var isLargePDF: Bool = false
    @Published var estimatedLoadTime: String = ""
    @Published var memoryUsage: String = ""

	// MARK: - Managers
	let searchManager = PDFSearchManager()
	let bookmarkManager = PDFBookmarkManager()
	let outlineManager = PDFOutlineManager()

    // MARK: - Constants
    private static let largePDFPageThreshold = 500
    private static let validationSamplePages = 3
    private static let loadDebounceNanoseconds: UInt64 = 100_000_000  // 0.1s
    private static let persistPageDelay: TimeInterval = 0.5
    private static let memoryPressureCooldown: TimeInterval = 5.0
    private static let loadEstimateBaseTime: TimeInterval = 2.0
    private static let loadEstimatePerPage: TimeInterval = 0.01
    private static let loadEstimateMinuteThreshold: TimeInterval = 60

    private let sessionKey = "DevReader.Session.v1"
	private var loadingTask: Task<Void, Never>?
	private var outlineTask: Task<Void, Never>?
	private var isHandlingMemoryPressure = false
	private var memoryPressureObserver: Any?
	private var persistPageWorkItem: DispatchWorkItem?
	private var isRestoringPage = false
	private let lastOpenedPDFKey = "DevReader.LastOpenedPDF.v1"
	private var managerCancellables = Set<AnyCancellable>()

	init() {
		// Forward objectWillChange from each manager so views observing PDFController still update
		searchManager.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &managerCancellables)
		bookmarkManager.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &managerCancellables)
		outlineManager.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &managerCancellables)

		setupMemoryPressureHandler()
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

	private func cleanupCurrentPDF() async {
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
        PerformanceMonitor.shared.trackPDFLoad(startTime)

        LoadingStateManager.shared.startPDFLoading("Loading PDF...")
        isLoadingPDF = true
        defer {
            isLoadingPDF = false
            LoadingStateManager.shared.stopPDFLoading()
        }

		guard FileManager.default.fileExists(atPath: url.path) else {
			logError(AppLog.pdf, "PDF file does not exist: \(url.path)")
			NotificationCenter.default.post(name: .pdfLoadError, object: url)
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
			NotificationCenter.default.post(name: .pdfLoadError, object: url)
			return
		}

		guard validateDocument(loadedDoc) else {
			logError(AppLog.pdf, "PDF document failed integrity check")
			NotificationCenter.default.post(name: .pdfLoadError, object: url)
			return
		}

		let pageCount = loadedDoc.pageCount
		isLargePDF = pageCount >= Self.largePDFPageThreshold

		if isLargePDF {
			estimatedLoadTime = estimateLoadTime(for: pageCount)
			updateMemoryUsage()
			LoadingStateManager.shared.updatePDFProgress(0.5, message: "Processing large PDF (\(pageCount) pages)...")
		}

		self.document = loadedDoc
		self.currentPDFURL = url

		PersistenceService.saveCodable(url, forKey: lastOpenedPDFKey)

		if isLargePDF {
			LoadingStateManager.shared.updatePDFProgress(0.8, message: "Building outline for large PDF...")
			outlineTask = Task {
				await outlineManager.rebuildOutlineMapAsync(from: document, isLargePDF: isLargePDF)
			}
		} else {
			outlineManager.rebuildOutlineMap(from: document)
		}

		loadPageForPDF(url)
		updateReadingProgress()
		bookmarkManager.loadBookmarks(for: currentPDFURL)
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

	// MARK: - Debounced Page Persistence

	func didScrollToPage(_ index: Int) {
		guard let doc = document, index >= 0, index < doc.pageCount else { return }
		currentPageIndex = index
		updateReadingProgress()
		schedulePersistPage()
	}

	private func schedulePersistPage() {
		guard !isRestoringPage else { return }
		persistPageWorkItem?.cancel()
		let workItem = DispatchWorkItem { @Sendable [weak self] in
			Task { @MainActor in
				guard let self = self, let url = self.currentPDFURL else { return }
				self.savePageForPDF(url)
			}
		}
		persistPageWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + Self.persistPageDelay, execute: workItem)
	}

	func flushPendingPersistence() {
		if let workItem = persistPageWorkItem {
			workItem.cancel()
			persistPageWorkItem = nil
			if let url = currentPDFURL {
				savePageForPDF(url)
			}
		}
	}

    func savePageForPDF(_ url: URL) {
        let pageKey = PersistenceService.key(sessionKey, for: url)
        PersistenceService.saveInt(currentPageIndex, forKey: pageKey)
    }

    private func loadPageForPDF(_ url: URL) {
		isRestoringPage = true
		defer { isRestoringPage = false }
        let pageKey = PersistenceService.key(sessionKey, for: url)
        let savedPage = PersistenceService.loadInt(forKey: pageKey) ?? 0
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
		let monitor = PerformanceMonitor.shared
		memoryUsage = monitor.formatBytes(monitor.memoryUsage)
	}

	// MARK: - Highlight and Notes Integration

	func captureHighlightToNotes() {
		guard currentPDFURL != nil else { return }
		let selectedText = PDFSelectionBridge.shared.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let text = selectedText, !text.isEmpty else {
			NotificationCenter.default.post(
				name: .showToast,
				object: ToastMessage(message: "Select text in the PDF first", type: .warning)
			)
			return
		}
		let note = NoteItem(
			title: "Highlight from page \(currentPageIndex + 1)",
			text: text,
			pageIndex: currentPageIndex,
			chapter: getCurrentChapter() ?? "Unknown Chapter"
		)
		NotificationCenter.default.post(name: .addNote, object: note)
		NotificationCenter.default.post(
			name: .showToast,
			object: ToastMessage(message: "Highlight captured as note", type: .success)
		)
	}

	private func getCurrentChapter() -> String? {
		if let chapter = outlineManager.outlineMap[currentPageIndex] {
			return chapter
		}
		for i in stride(from: currentPageIndex - 1, through: 0, by: -1) {
			if let chapter = outlineManager.outlineMap[i] {
				return chapter
			}
		}
		return document?.outlineRoot?.label
	}

	func addStickyNote() {
		guard currentPDFURL != nil else { return }
		let selectedText = PDFSelectionBridge.shared.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
		let noteText = (selectedText?.isEmpty == false) ? selectedText! : ""
		let stickyNote = NoteItem(
			title: "Sticky note — page \(currentPageIndex + 1)",
			text: noteText,
			pageIndex: currentPageIndex,
			chapter: getCurrentChapter() ?? "Unknown Chapter",
			tags: ["sticky"]
		)
		NotificationCenter.default.post(name: .addNote, object: stickyNote)
		NotificationCenter.default.post(
			name: .showToast,
			object: ToastMessage(message: "Sticky note added", type: .success)
		)
	}
}
