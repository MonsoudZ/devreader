//
//  DevReaderUITests.swift
//  DevReaderUITests
//
//  Created by Monsoud Zanaty on 9/22/25.
//

import XCTest

final class DevReaderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Core UI Tests

    @MainActor
    func testAppLaunchShowsMainUI() throws {
        if ProcessInfo.processInfo.environment["DEVREADER_UI_E2E"] != "1" {
            throw XCTSkip("UI test skipped (set DEVREADER_UI_E2E=1 to enable)")
        }

        let app = XCUIApplication()
        app.launch()

        // Verify Open and Import buttons exist
        XCTAssertTrue(app.buttons["openPDFButton"].waitForExistence(timeout: 5), "Open PDF button should exist")
        XCTAssertTrue(app.buttons["importPDFButton"].exists, "Import PDF button should exist")

        // Verify Library and Tools toggles exist
        XCTAssertTrue(app.toggles["toggleLibrary"].exists, "Library toggle should exist")
        XCTAssertTrue(app.toggles["toggleTools"].exists, "Tools toggle should exist")
    }

    @MainActor
    func testToggleLibraryPanel() throws {
        if ProcessInfo.processInfo.environment["DEVREADER_UI_E2E"] != "1" {
            throw XCTSkip("UI test skipped (set DEVREADER_UI_E2E=1 to enable)")
        }

        let app = XCUIApplication()
        app.launch()

        let libraryToggle = app.toggles["toggleLibrary"]
        XCTAssertTrue(libraryToggle.waitForExistence(timeout: 5), "Library toggle should exist")

        // Toggle library off
        libraryToggle.click()

        // Toggle library back on
        libraryToggle.click()

        // Verify toggle is still functional
        XCTAssertTrue(libraryToggle.exists, "Library toggle should still exist after toggling")
    }

    @MainActor
    func testToggleToolsPanel() throws {
        if ProcessInfo.processInfo.environment["DEVREADER_UI_E2E"] != "1" {
            throw XCTSkip("UI test skipped (set DEVREADER_UI_E2E=1 to enable)")
        }

        let app = XCUIApplication()
        app.launch()

        let toolsToggle = app.toggles["toggleTools"]
        XCTAssertTrue(toolsToggle.waitForExistence(timeout: 5), "Tools toggle should exist")

        // Toggle tools off
        toolsToggle.click()

        // Toggle tools back on
        toolsToggle.click()

        // Verify toggle is still functional
        XCTAssertTrue(toolsToggle.exists, "Tools toggle should still exist after toggling")
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        if ProcessInfo.processInfo.environment["DEVREADER_UI_E2E"] != "1" {
            throw XCTSkip("UI launch performance test skipped (set DEVREADER_UI_E2E=1 to enable)")
        }
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
