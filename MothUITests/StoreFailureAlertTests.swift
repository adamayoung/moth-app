//  StoreFailureAlertTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class StoreFailureAlertTests: MothTestCase {

    override var additionalLaunchArguments: [String] {
        ["-UITestStoreFailure", "1"]
    }

    @MainActor
    func testAlertShowsItsTextAndOnlyQuitWithNoMainWindow() {
        let screen = StoreFailureAlertScreen(app: app)

        XCTAssertTrue(screen.alert.waitForExistence(timeout: 10), app.debugDescription)

        XCTAssertTrue(screen.text("Moth can’t open your data.").exists)
        XCTAssertTrue(
            screen.text(
                "Quit, then open Moth again. If this keeps happening, the data may come from a newer version of Moth."
            ).exists
        )
        XCTAssertTrue(screen.quitButton.exists)
        XCTAssertEqual(screen.buttons.count, 1)
        XCTAssertFalse(MainWindowScreen(app: app).sidebar.exists)
    }

    @MainActor
    func testQuitEndsTheApp() {
        let screen = StoreFailureAlertScreen(app: app)

        XCTAssertTrue(screen.quitButton.waitForExistence(timeout: 10))
        screen.quitButton.click()

        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

}
