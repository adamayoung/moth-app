//  AppLaunchTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class AppLaunchTests: MothTestCase {

    @MainActor
    func testUITestingLaunchOpensAWindow() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

}
