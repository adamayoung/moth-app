//  VariableSheetTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Mirrors `SeedData` by hand: Seeded Environment holds `host` = https://example.com, and Seeded Collection holds
/// `apiVersion` = v1.
final class VariableSheetTests: MothTestCase {

    @MainActor
    private func openSheet(on name: String, _ item: String = "Edit\u{2026}") -> VariableSheetScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText(name).waitForExistence(timeout: 10))
        screen.chooseFromContextMenu(on: name, item)
        let sheet = VariableSheetScreen(app: app)
        XCTAssertTrue(sheet.doneButton.waitForExistence(timeout: 10))
        return sheet
    }

    @MainActor
    func testSheetShowsTheColumnsAndTheVariable() {
        let sheet = openSheet(on: "Seeded Environment")

        XCTAssertTrue(sheet.text("Seeded Environment").exists)
        for column in ["Enabled", "Variable", "Initial Value", "Current Value", "Secret"] {
            XCTAssertTrue(sheet.text(column).exists, "The sheet is missing \(column)")
        }
        XCTAssertEqual(sheet.name(at: 0).value as? String, "host")
        XCTAssertEqual(sheet.initialValue(at: 0).value as? String, "https://example.com")
        XCTAssertEqual(sheet.currentValue(at: 0).value as? String, "https://example.com")
        XCTAssertEqual(sheet.enabledToggle(at: 0).value as? Int, 1)
        XCTAssertEqual(sheet.secretToggle(at: 0).value as? Int, 0)
    }

    @MainActor
    func testAddingARowFocusesItsNameAndRemovingARowTakesItAway() {
        let sheet = openSheet(on: "Seeded Environment")

        sheet.addButton.click()
        XCTAssertTrue(sheet.waitForRowCount(2))
        XCTAssertTrue(sheet.waitForFocus(on: sheet.name(at: 1)))
        app.typeText("port\n")
        XCTAssertEqual(sheet.name(at: 1).value as? String, "port")

        sheet.removeButton(at: 0).click()

        XCTAssertTrue(sheet.waitForRowCount(1))
        XCTAssertEqual(sheet.name(at: 0).value as? String, "port")
    }

    @MainActor
    func testAnEditStillInItsFieldSavesWhenTheSheetCloses() {
        var sheet = openSheet(on: "Seeded Environment")

        // No colon: `typeText` drops every one, in any field.
        sheet.replaceText(in: sheet.currentValue(at: 0), with: "edited.example")
        sheet.close()

        sheet = openSheet(on: "Seeded Environment")
        XCTAssertEqual(sheet.currentValue(at: 0).value as? String, "edited.example")
        XCTAssertEqual(sheet.initialValue(at: 0).value as? String, "https://example.com")
    }

    @MainActor
    func testACollectionOffersVariablesAndAFolderDoesNot() {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))

        let menu = screen.contextMenu(on: "Users")
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertFalse(menu.menuItems["Variables\u{2026}"].exists)
        screen.closeMenu()

        let sheet = openSheet(on: "Seeded Collection", "Variables\u{2026}")

        XCTAssertTrue(sheet.text("Seeded Collection").exists)
        XCTAssertTrue(sheet.text("Initial Value").exists)
        XCTAssertEqual(sheet.name(at: 0).value as? String, "apiVersion")
        XCTAssertEqual(sheet.currentValue(at: 0).value as? String, "v1")
    }

    @MainActor
    func testAGlobalIsAddedToTheGlobalsSheetAndStays() {
        var sheet = openSheet(on: "Globals")
        XCTAssertEqual(sheet.rowCount, 0)

        sheet.addButton.click()
        XCTAssertTrue(sheet.waitForRowCount(1))
        XCTAssertTrue(sheet.waitForFocus(on: sheet.name(at: 0)))
        app.typeText("region\n")
        sheet.close()

        sheet = openSheet(on: "Globals")
        XCTAssertEqual(sheet.name(at: 0).value as? String, "region")
    }

    @MainActor
    func testASecretShowsOneSecureFieldThatShowAndHideReveal() {
        let sheet = openSheet(on: "Seeded Environment")

        sheet.secretToggle(at: 0).click()

        XCTAssertTrue(sheet.secureSecretField.waitForExistence(timeout: 10))
        XCTAssertFalse(sheet.initialValue(at: 0).exists)
        XCTAssertFalse(sheet.currentValue(at: 0).exists)
        XCTAssertFalse(sheet.revealedSecretField.exists)
        XCTAssertEqual(sheet.secretVisibilityButton.label, "Show")

        sheet.secretVisibilityButton.click()

        XCTAssertTrue(sheet.revealedSecretField.waitForExistence(timeout: 10))
        XCTAssertEqual(sheet.revealedSecretField.value as? String, "https://example.com")
        XCTAssertFalse(sheet.secureSecretField.exists)
        XCTAssertEqual(sheet.secretVisibilityButton.label, "Hide")

        sheet.secretVisibilityButton.click()

        XCTAssertTrue(sheet.secureSecretField.waitForExistence(timeout: 10))
        XCTAssertFalse(sheet.revealedSecretField.exists)
    }

    @MainActor
    func testTurningOffSecretRestoresBothValues() {
        let sheet = openSheet(on: "Seeded Environment")
        sheet.secretToggle(at: 0).click()
        XCTAssertTrue(sheet.secureSecretField.waitForExistence(timeout: 10))

        sheet.secretToggle(at: 0).click()

        XCTAssertTrue(sheet.initialValue(at: 0).waitForExistence(timeout: 10))
        XCTAssertEqual(sheet.initialValue(at: 0).value as? String, "https://example.com")
        XCTAssertEqual(sheet.currentValue(at: 0).value as? String, "https://example.com")
    }

}
