//  AppShellTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class AppShellTests: MothTestCase {

    @MainActor
    func testSidebarShowsEachSectionWithItsEmptyText() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.sidebar.waitForExistence(timeout: 10))

        for text in [
            "Collections", "No Collections",
            "Environments", "No Environments",
            "History", "No History"
        ] {
            XCTAssertTrue(screen.sidebarText(text).exists, "Sidebar is missing \"\(text)\"")
        }
    }

    @MainActor
    func testDetailShowsTabStripAndBothPanesWithTheirEmptyText() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.tabStrip.waitForExistence(timeout: 10))

        XCTAssertTrue(screen.requestEditorText("No Request Open").exists)
        XCTAssertTrue(screen.requestEditorText("Open a request from the sidebar to edit and send it.").exists)

        XCTAssertTrue(screen.responseText("No Response").exists)
        XCTAssertTrue(screen.responseText("Send a request to see its response here.").exists)
    }

    @MainActor
    func testEachDetailRegionHasAnAccessibilityLabel() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.tabStrip.waitForExistence(timeout: 10))

        XCTAssertEqual(screen.tabStrip.label, "Request Tabs")
        XCTAssertEqual(screen.requestEditorPane.label, "Request Editor")
        XCTAssertEqual(screen.responsePane.label, "Response")
    }

    @MainActor
    func testTabStripSitsUnderTheToolbarWithThePanesStackedBelowIt() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.tabStrip.waitForExistence(timeout: 10))

        let window = screen.window.frame
        let tabStrip = screen.tabStrip.frame
        let editor = screen.requestEditorPane.frame
        let response = screen.responsePane.frame

        XCTAssertEqual(tabStrip.minY, screen.toolbar.frame.maxY, accuracy: 2)
        XCTAssertEqual(tabStrip.maxX, window.maxX, accuracy: 1)
        XCTAssertLessThan(editor.midY, window.midY)
        XCTAssertGreaterThan(response.midY, window.midY)
        XCTAssertEqual(editor.midX, tabStrip.midX, accuracy: 1)
        XCTAssertEqual(response.midX, tabStrip.midX, accuracy: 1)
    }

}
