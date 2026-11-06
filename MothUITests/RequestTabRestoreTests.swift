//  RequestTabRestoreTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class RequestTabRestoreTests: MothTestCase {

    @MainActor
    func testTabsAndTheSelectedTabReturnAfterARelaunch() {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        screen.select("List Users")
        XCTAssertTrue(screen.requestTab("GET List Users").waitForExistence(timeout: 10))
        screen.select("Create User")
        XCTAssertTrue(screen.requestTab("POST Create User").waitForExistence(timeout: 10))
        screen.requestTab("GET List Users").click()
        XCTAssertTrue(screen.requestEditorText("List Users").waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments += ["-UITestRestoresTabs", "1"]
        app.launch()

        XCTAssertTrue(screen.requestTab("POST Create User").waitForExistence(timeout: 10))
        XCTAssertTrue(screen.requestTab("GET List Users").exists)
        XCTAssertEqual(screen.requestTabs.count, 2)
        XCTAssertTrue(screen.requestEditorText("List Users").waitForExistence(timeout: 10))
    }

}
