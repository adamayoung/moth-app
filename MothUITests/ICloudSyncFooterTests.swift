//  ICloudSyncFooterTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class ICloudSyncFooterTests: MothTestCase {

    @MainActor
    func testFooterShowsItsTextAndHelpWithNoContainer() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.iCloudSyncOffFooter.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(screen.iCloudSyncOffFooter.label, "iCloud Sync Off")

        screen.iCloudSyncOffFooter.hover()

        let help = app.descendants(matching: .helpTag).firstMatch
        XCTAssertTrue(help.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(help.label, "This build has no iCloud container, so your data stays on this Mac.")
    }

}
