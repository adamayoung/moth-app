//  ICloudSyncOnFooterTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class ICloudSyncOnFooterTests: MothTestCase {

    override var additionalLaunchArguments: [String] {
        ["-UITestICloudSync", "1"]
    }

    @MainActor
    func testFooterIsAbsentWhenSynced() {
        let screen = MainWindowScreen(app: app)

        XCTAssertTrue(screen.sidebar.waitForExistence(timeout: 10))

        XCTAssertFalse(screen.iCloudSyncOffFooter.exists)
    }

}
