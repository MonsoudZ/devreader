import XCTest
import Combine
@testable import DevReader

@MainActor
final class TabManagerTests: XCTestCase {
    var tabManager: TabManager!

    override func setUp() async throws {
        tabManager = TabManager()
    }

    override func tearDown() async throws {
        tabManager = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.title, "New Tab")
        XCTAssertEqual(tabManager.activeTabID, tabManager.tabs.first?.id)
        XCTAssertFalse(tabManager.showTabBar, "Tab bar should be hidden with only 1 tab")
    }

    // MARK: - Adding Tabs

    func testAddTab() {
        let newTab = tabManager.addTab()

        XCTAssertNotNil(newTab)
        XCTAssertEqual(tabManager.tabs.count, 2)
        XCTAssertEqual(tabManager.activeTabID, newTab?.id, "New tab should become active")
        XCTAssertTrue(tabManager.showTabBar, "Tab bar should show with 2+ tabs")
    }

    func testAddTabReturnsNilAtMaxLimit() {
        // Fill to max
        for _ in 1..<TabManager.maxTabs {
            tabManager.addTab()
        }
        XCTAssertEqual(tabManager.tabs.count, TabManager.maxTabs)

        // One more should fail
        let overflow = tabManager.addTab()
        XCTAssertNil(overflow)
        XCTAssertEqual(tabManager.tabs.count, TabManager.maxTabs)
    }

    // MARK: - Closing Tabs

    func testCloseOnlyTabClearsIt() {
        let tabID = tabManager.tabs[0].id

        let removed = tabManager.closeTab(tabID)

        XCTAssertFalse(removed, "Closing the only tab should not remove it")
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs[0].title, "New Tab")
        XCTAssertNil(tabManager.tabs[0].url)
    }

    func testCloseActiveTabSwitchesToNeighbor() {
        let firstTabID = tabManager.tabs[0].id
        let secondTab = tabManager.addTab()!
        let thirdTab = tabManager.addTab()!

        // Active is now thirdTab; close it
        let removed = tabManager.closeTab(thirdTab.id)

        XCTAssertTrue(removed)
        XCTAssertEqual(tabManager.tabs.count, 2)
        // Should switch to nearest remaining tab
        XCTAssertTrue(
            tabManager.activeTabID == firstTabID || tabManager.activeTabID == secondTab.id,
            "Active tab should switch to a remaining tab"
        )
    }

    func testCloseInactiveTabKeepsActiveTab() {
        let _ = tabManager.addTab()!
        let secondTab = tabManager.addTab()!
        // Active is secondTab (most recently added)
        let activeBeforeClose = tabManager.activeTabID

        // Close the first tab (index 0), which is not active
        let firstTabID = tabManager.tabs[0].id
        if firstTabID != activeBeforeClose {
            let removed = tabManager.closeTab(firstTabID)
            XCTAssertTrue(removed)
            XCTAssertEqual(tabManager.activeTabID, activeBeforeClose, "Active tab should not change")
        }
    }

    // MARK: - Switching Tabs

    func testSwitchToTab() {
        let firstTabID = tabManager.tabs[0].id
        let _ = tabManager.addTab()!
        // Active is now the second tab

        tabManager.switchTo(firstTabID)

        XCTAssertEqual(tabManager.activeTabID, firstTabID)
    }

    func testSwitchToInvalidTabIsNoOp() {
        let bogusID = UUID()
        let activeBefore = tabManager.activeTabID

        tabManager.switchTo(bogusID)

        XCTAssertEqual(tabManager.activeTabID, activeBefore)
    }

    func testActiveTabChangedFires() {
        var receivedControllers: [PDFController] = []
        let cancellable = tabManager.activeTabChanged.sink { controller in
            receivedControllers.append(controller)
        }

        let _ = tabManager.addTab()
        // addTab calls switchTo internally, which fires activeTabChanged

        XCTAssertFalse(receivedControllers.isEmpty, "activeTabChanged should have fired")
        _ = cancellable
    }

    // MARK: - Open Same URL Reuses Existing Tab

    func testOpenSameURLReusesExistingTab() {
        let url = URL(fileURLWithPath: "/tmp/test-reuse.pdf")

        // Open in the empty first tab
        tabManager.openInTab(url: url, title: "Test PDF")
        let tabCountAfterFirst = tabManager.tabs.count
        let activeAfterFirst = tabManager.activeTabID

        // Open the same URL again
        tabManager.openInTab(url: url, title: "Test PDF")

        XCTAssertEqual(tabManager.tabs.count, tabCountAfterFirst, "Should not create a new tab for same URL")
        XCTAssertEqual(tabManager.activeTabID, activeAfterFirst, "Should switch to existing tab")
    }

    // MARK: - Open URL in Empty Tab Reuses It

    func testOpenURLInEmptyTabReusesIt() {
        // The initial tab is empty (no document, no URL)
        let initialTabID = tabManager.tabs[0].id
        let url = URL(fileURLWithPath: "/tmp/test-empty.pdf")

        tabManager.openInTab(url: url, title: "Empty Tab Reuse")

        XCTAssertEqual(tabManager.tabs.count, 1, "Should reuse the empty tab, not create a new one")
        XCTAssertEqual(tabManager.tabs[0].id, initialTabID)
        XCTAssertEqual(tabManager.tabs[0].url, url)
        XCTAssertEqual(tabManager.tabs[0].title, "Empty Tab Reuse")
    }

    // MARK: - Close Active Tab (convenience)

    func testCloseActiveTab() {
        let _ = tabManager.addTab()!
        let activeID = tabManager.activeTabID

        tabManager.closeActiveTab()

        XCTAssertFalse(tabManager.tabs.contains(where: { $0.id == activeID }),
                       "Active tab should have been removed")
        XCTAssertEqual(tabManager.tabs.count, 1)
    }
}
