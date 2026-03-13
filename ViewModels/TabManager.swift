import Foundation
import SwiftUI
import Combine

/// Describes a single open tab in the PDF viewer.
struct PDFTab: Identifiable {
    let id: UUID
    var title: String
    let pdfController: PDFController
    var url: URL?

    init(
        id: UUID = UUID(),
        title: String = "New Tab",
        pdfController: PDFController,
        url: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.pdfController = pdfController
        self.url = url
    }
}

/// Manages multiple PDF tabs within a single window.
/// Each tab owns its own `PDFController`. The active tab's controller is
/// surfaced as `activeController` for backward compatibility.
@MainActor
final class TabManager: ObservableObject {

    // MARK: - Constants

    static let maxTabs = 10

    // MARK: - Published State

    @Published private(set) var tabs: [PDFTab] = []
    @Published var activeTabID: UUID

    /// True when there are 2+ tabs (used to show/hide the tab bar).
    var showTabBar: Bool { tabs.count >= 2 }

    /// The controller for the currently active tab.
    var activeController: PDFController {
        guard let tab = tabs.first(where: { $0.id == activeTabID }) else {
            // Should never happen; fallback to first tab.
            return tabs[0].pdfController
        }
        return tab.pdfController
    }

    // MARK: - Dependencies

    private let loadingStateManager: LoadingStateManager
    private let performanceMonitor: PerformanceMonitor

    // MARK: - Observation

    /// Fires whenever the active tab changes so parent views can re-subscribe
    /// to the new controller's publishers.
    let activeTabChanged = PassthroughSubject<PDFController, Never>()

    private var tabCancellables: [UUID: AnyCancellable] = [:]

    // MARK: - Init

    init(
        loadingStateManager: LoadingStateManager = .shared,
        performanceMonitor: PerformanceMonitor = .shared
    ) {
        self.loadingStateManager = loadingStateManager
        self.performanceMonitor = performanceMonitor

        // Create the initial empty tab.
        let controller = PDFController(
            loadingStateManager: loadingStateManager,
            performanceMonitor: performanceMonitor
        )
        let tab = PDFTab(pdfController: controller)
        self.tabs = [tab]
        self.activeTabID = tab.id
        observeTabTitle(tab)
    }

    // MARK: - Tab Operations

    /// Add a new empty tab and switch to it.
    /// Returns the new tab, or `nil` if the maximum tab count has been reached.
    @discardableResult
    func addTab() -> PDFTab? {
        guard tabs.count < Self.maxTabs else { return nil }
        let controller = PDFController(
            loadingStateManager: loadingStateManager,
            performanceMonitor: performanceMonitor
        )
        let tab = PDFTab(pdfController: controller)
        tabs.append(tab)
        observeTabTitle(tab)
        switchTo(tab.id)
        return tab
    }

    /// Open a URL in a new tab, or switch to an existing tab if already open.
    func openInTab(url: URL, title: String? = nil) {
        // Check if this URL is already open in a tab.
        if let existing = tabs.first(where: { $0.url == url }) {
            switchTo(existing.id)
            return
        }

        // Try to reuse the active tab if it has no document loaded.
        if activeController.document == nil && activeTab?.url == nil {
            let tabTitle = title ?? url.deletingPathExtension().lastPathComponent
            updateActiveTab(url: url, title: tabTitle)
            activeController.open(url: url)
            return
        }

        // Otherwise, open in a new tab.
        guard tabs.count < Self.maxTabs else {
            // At max tabs — load into current tab instead of silently failing.
            let tabTitle = title ?? url.deletingPathExtension().lastPathComponent
            updateActiveTab(url: url, title: tabTitle)
            activeController.open(url: url)
            return
        }

        let controller = PDFController(
            loadingStateManager: loadingStateManager,
            performanceMonitor: performanceMonitor
        )
        let tabTitle = title ?? url.deletingPathExtension().lastPathComponent
        let tab = PDFTab(pdfController: controller, url: url)
        tabs.append(tab)
        observeTabTitle(tab)
        switchTo(tab.id)
        controller.open(url: url)
        // Update tab title after switching (switchTo already set activeTabID).
        if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[idx].title = tabTitle
            tabs[idx].url = url
        }
    }

    /// Open a `LibraryItem` in a tab, reusing an existing tab if the URL matches.
    func openInTab(libraryItem: LibraryItem) {
        let resolvedURL = libraryItem.resolveURLFromBookmark() ?? libraryItem.url
        let title = resolvedURL.deletingPathExtension().lastPathComponent

        // Check if this URL is already open in a tab.
        if let existing = tabs.first(where: { $0.url == resolvedURL }) {
            switchTo(existing.id)
            return
        }

        // Reuse current tab if empty.
        if activeController.document == nil && activeTab?.url == nil {
            updateActiveTab(url: resolvedURL, title: title)
            activeController.load(libraryItem: libraryItem)
            return
        }

        guard tabs.count < Self.maxTabs else {
            updateActiveTab(url: resolvedURL, title: title)
            activeController.load(libraryItem: libraryItem)
            return
        }

        let controller = PDFController(
            loadingStateManager: loadingStateManager,
            performanceMonitor: performanceMonitor
        )
        let tab = PDFTab(pdfController: controller, url: resolvedURL)
        tabs.append(tab)
        observeTabTitle(tab)
        switchTo(tab.id)
        controller.load(libraryItem: libraryItem)
        if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[idx].title = title
            tabs[idx].url = resolvedURL
        }
    }

    /// Switch to a tab by its ID.
    func switchTo(_ tabID: UUID) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        activeTabID = tabID
        activeTabChanged.send(activeController)
    }

    /// Close a tab by its ID. If it is the last tab, clear its document instead.
    /// Returns `true` if the tab was removed, `false` if it was just cleared.
    @discardableResult
    func closeTab(_ tabID: UUID) -> Bool {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return false }

        // If this is the only tab, just clear it.
        if tabs.count == 1 {
            tabs[idx].pdfController.clearSession()
            tabs[idx].title = "New Tab"
            tabs[idx].url = nil
            return false
        }

        // Flush state and cancel async work before closing.
        let closingController = tabs[idx].pdfController
        closingController.flushPendingPersistence()
        closingController.searchManager.cancelSearchTask()
        tabCancellables.removeValue(forKey: tabID)

        let wasActive = tabID == activeTabID
        tabs.remove(at: idx)

        // Defer deallocation to avoid crash in PDFSearchManager deinit
        // when Swift runtime cleans up task-local storage synchronously
        Task { @MainActor in _ = closingController }

        if wasActive {
            // Switch to the nearest tab.
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[newIdx].id
            activeTabChanged.send(activeController)
        }
        return true
    }

    /// Close the currently active tab. Convenience for Cmd+W.
    func closeActiveTab() {
        closeTab(activeTabID)
    }

    // MARK: - Flush All

    /// Flush pending persistence for all tab controllers.
    func flushAllPendingPersistence() {
        for tab in tabs {
            tab.pdfController.flushPendingPersistence()
            tab.pdfController.annotationManager.flushPendingPersistence()
        }
    }

    // MARK: - Private Helpers

    private var activeTab: PDFTab? {
        tabs.first(where: { $0.id == activeTabID })
    }

    private func updateActiveTab(url: URL, title: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[idx].url = url
        tabs[idx].title = title
    }

    /// Observe when a tab's PDFController loads a document and update the tab title.
    private func observeTabTitle(_ tab: PDFTab) {
        let cancellable = tab.pdfController.$currentPDFURL
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self else { return }
                if let idx = self.tabs.firstIndex(where: { $0.id == tab.id }) {
                    self.tabs[idx].title = url.deletingPathExtension().lastPathComponent
                    self.tabs[idx].url = url
                }
            }
        tabCancellables[tab.id] = cancellable
    }
}
