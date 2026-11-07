//  CurlImportTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// The commands have no colon, because `typeText` can drop one on a Mac. The unit tests cover full URLs.
final class CurlImportTests: MothTestCase {

    @MainActor
    private func openSheet() -> (window: MainWindowScreen, sheet: CurlImportScreen) {
        let window = MainWindowScreen(app: app)
        XCTAssertTrue(window.sidebarText("Seeded Environment").waitForExistence(timeout: 10))
        window.chooseFromFileMenu("Import cURL\u{2026}")

        let sheet = CurlImportScreen(app: app)
        XCTAssertTrue(sheet.title.waitForExistence(timeout: 10))
        return (window, sheet)
    }

    @MainActor
    func testImportStaysDisabledUntilThereIsText() {
        let (_, sheet) = openSheet()

        XCTAssertFalse(sheet.importButton.isEnabled)

        sheet.type("curl example.com/users")

        XCTAssertTrue(sheet.importButton.isEnabled)
    }

    @MainActor
    func testCancelClosesTheSheet() {
        let (window, sheet) = openSheet()

        sheet.cancelButton.click()

        XCTAssertTrue(ImportResultScreen(app: app).waitForDismissal())
        XCTAssertEqual(window.requestTabs.count, 0)
    }

    @MainActor
    func testImportOpensTheRequestInATab() {
        let (window, sheet) = openSheet()

        sheet.type("curl -X POST example.com/users")
        sheet.importButton.click()

        XCTAssertTrue(ImportResultScreen(app: app).waitForDismissal())
        XCTAssertTrue(window.sidebarText("POST /users").waitForExistence(timeout: 10))
        XCTAssertEqual(window.requestTabs.count, 1)
    }

    @MainActor
    func testInvalidTextShowsAMessageAndKeepsTheSheet() {
        let (window, sheet) = openSheet()

        sheet.type("hello")
        sheet.importButton.click()

        XCTAssertTrue(sheet.problem.waitForExistence(timeout: 10))
        XCTAssertEqual(sheet.problem.value as? String, "This isn\u{2019}t a valid cURL command.")
        XCTAssertTrue(sheet.title.exists)
        XCTAssertEqual(window.requestTabs.count, 0)
    }

    @MainActor
    func testIgnoredFlagsAreListedAfterTheImport() {
        let (window, sheet) = openSheet()

        sheet.type("curl -s example.com/users")
        sheet.importButton.click()

        let result = ImportResultScreen(app: app)
        XCTAssertTrue(result.skippedText.waitForExistence(timeout: 10))
        XCTAssertTrue(result.text("Ignored: -s").exists)

        result.doneButton.click()

        XCTAssertTrue(result.waitForDismissal())
        XCTAssertEqual(window.requestTabs.count, 1)
    }

    @MainActor
    func testTheMenuItemIsUnavailableWhileTheSheetIsUp() {
        let (window, _) = openSheet()

        window.openFileMenu()
        XCTAssertFalse(window.fileMenuItem("Import cURL\u{2026}").isEnabled)
        XCTAssertFalse(window.fileMenuItem("Import\u{2026}").isEnabled)
        window.closeMenu()
    }

}
