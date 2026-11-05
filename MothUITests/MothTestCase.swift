//  MothTestCase.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

class MothTestCase: XCTestCase {

    private(set) var app: XCUIApplication!

    var additionalLaunchArguments: [String] {
        []
    }

    override func setUp() async throws {
        continueAfterFailure = false
        await launchApp()
    }

    @MainActor
    private func launchApp() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting", "1",
            "-ApplePersistenceIgnoreState", "YES",
            "-NSShowNonLocalizedStrings", "YES"
        ] + additionalLaunchArguments
        app.launch()
        self.app = app
    }

}
