//  ImportTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

final class ImportTests: MothTestCase {

    /// The licensed files, read in place. The result text mirrors what `PostmanImportSummaryTests` pins.
    private static let fixtures = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Packages/PostmanKit/Tests/PostmanKitTests/Fixtures")

    /// Mirrors `DependencyProvider.uiTestImportFileKey`.
    private static let importFileKey = "MOTH_UI_TEST_IMPORT_FILE"

    @MainActor
    private func importing(_ fixture: String) throws -> (window: MainWindowScreen, result: ImportResultScreen) {
        let text = try String(contentsOf: Self.fixtures.appending(path: fixture), encoding: .utf8)
        app.terminate()
        app.launchEnvironment[Self.importFileKey] = text
        app.launch()

        let window = MainWindowScreen(app: app)
        XCTAssertTrue(window.sidebarText("Seeded Environment").waitForExistence(timeout: 10))
        window.chooseFromFileMenu("Import\u{2026}")

        let result = ImportResultScreen(app: app)
        XCTAssertTrue(result.sheet.waitForExistence(timeout: 10))
        return (window, result)
    }

    @MainActor
    func testImportsACollectionIntoTheSidebar() throws {
        let (window, result) = try importing("postman-collection-transformer/v2.1.0/nestedEntities.json")

        result.doneButton.click()

        XCTAssertTrue(window.sidebarText("auth-v1").waitForExistence(timeout: 10))
    }

    @MainActor
    func testImportsAnEnvironmentIntoTheList() throws {
        let (window, result) = try importing("postman-cli-action/postman-echo-environment.json")

        result.doneButton.click()

        XCTAssertTrue(window.sidebarText("Postman Echo Environment").waitForExistence(timeout: 10))
    }

    @MainActor
    func testResultSaysWhatWasImportedAndSkipped() throws {
        let (_, result) = try importing("postman-collection-transformer/v2.1.0/nestedEntities.json")

        XCTAssertTrue(result.text("Imported \u{201C}auth-v1\u{201D}: 2 requests, 1 folder.").exists)
        XCTAssertTrue(
            result.text("Skipped 8 scripts, 1 folder variable, 5 descriptions and 1 OAuth 1.0 auth.").exists
        )
    }

    @MainActor
    func testResultSaysNothingAboutSkippingWhenNothingWas() throws {
        let (_, result) = try importing("postman-code-generators/formdataCollection.json")

        XCTAssertTrue(result.text("Imported \u{201C}Multipart/form-data\u{201D}: 1 request, 0 folders.").exists)
        XCTAssertFalse(result.skippedText.exists)
    }

    @MainActor
    func testRefusesAFileOfAnotherKind() throws {
        let (window, result) = try importing("postman-collection-transformer/v2.1.0/proper-description-parsing.json")

        XCTAssertTrue(result.text("This file isn\u{2019}t a Postman Collection v2.1 or Environment.").exists)
        XCTAssertFalse(result.skippedText.exists)

        result.doneButton.click()

        XCTAssertTrue(result.waitForDismissal())
        XCTAssertFalse(window.sidebarText("proper-description-parsing").exists)
    }

}
