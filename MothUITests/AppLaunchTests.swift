//  AppLaunchTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class AppLaunchTests: MothTestCase {

    @MainActor
    func testUITestingLaunchOpensAWindow() {
        XCTAssertTrue(MainWindowScreen(app: app).window.waitForExistence(timeout: 10))
    }

}
