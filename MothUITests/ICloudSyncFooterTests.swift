//  ICloudSyncFooterTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class ICloudSyncFooterTests: MothTestCase {

    @MainActor
    func testFooterShowsItsTextAndHelpWithNoContainer() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.iCloudSyncOffFooter.waitForExistence(timeout: 10))
        XCTAssertEqual(screen.iCloudSyncOffFooter.label, "iCloud Sync Off")
        XCTAssertEqual(
            screen.iCloudSyncOffFooter.value as? String,
            "This build has no iCloud container, so your data stays on this Mac."
        )

        screen.iCloudSyncOffFooter.hover()

        XCTAssertTrue(app.descendants(matching: .helpTag).firstMatch.waitForExistence(timeout: 10))
    }

}
