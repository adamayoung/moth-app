//  EnvironmentsTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Mirrors `SeedData` by hand: Seeded Environment holds one variable and is active, and Staging holds six.
final class EnvironmentsTests: MothTestCase {

    @MainActor
    private func seededScreen() -> MainWindowScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Environment").waitForExistence(timeout: 10))
        return screen
    }

    @MainActor
    func testCreatesRenamesAndDeletesAnEnvironment() {
        let screen = seededScreen()

        screen.chooseFromFileMenu("New Environment")
        screen.finishRename(typing: "Production")
        XCTAssertTrue(screen.sidebarText("Production").waitForExistence(timeout: 10))

        screen.chooseFromContextMenu(on: "Production", "Rename")
        screen.finishRename(typing: "Live")
        XCTAssertTrue(screen.sidebarText("Live").waitForExistence(timeout: 10))
        XCTAssertFalse(screen.sidebarText("Production").exists)

        screen.chooseFromContextMenu(on: "Live", "Delete\u{2026}")
        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("You can\u{2019}t undo this.").exists)
        screen.alertButton("Delete").click()

        XCTAssertTrue(screen.waitForRowToDisappear("Live"))
    }

    @MainActor
    func testGlobalsIsFirstAndOffersNoRenameOrDelete() {
        let screen = seededScreen()

        let tops = ["Globals", "Seeded Environment", "Staging"].map { screen.sidebarText($0).frame.minY }
        XCTAssertEqual(tops, tops.sorted())

        let menu = screen.contextMenu(on: "Globals")
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertTrue(menu.menuItems["Edit\u{2026}"].exists)
        XCTAssertFalse(menu.menuItems["Rename"].exists)
        XCTAssertFalse(menu.menuItems["Delete\u{2026}"].exists)
    }

    @MainActor
    func testAnEnvironmentOffersEditRenameAndDelete() {
        let screen = seededScreen()

        let menu = screen.contextMenu(on: "Staging")

        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        for item in ["Edit\u{2026}", "Rename", "Delete\u{2026}"] {
            XCTAssertTrue(menu.menuItems[item].exists, "Staging is missing \(item)")
        }
    }

    @MainActor
    func testDeleteAlertCountsVariablesInThePlural() {
        let screen = seededScreen()

        screen.chooseFromContextMenu(on: "Staging", "Delete\u{2026}")

        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("Delete \u{201C}Staging\u{201D}?").exists)
        XCTAssertTrue(screen.alertText("This deletes its 6 variables. You can\u{2019}t undo this.").exists)
        XCTAssertTrue(screen.alertButton("Delete").exists)
        XCTAssertTrue(screen.alertButton("Cancel").exists)
    }

    @MainActor
    func testDeleteAlertCountsAVariableInTheSingular() {
        let screen = seededScreen()

        screen.chooseFromContextMenu(on: "Seeded Environment", "Delete\u{2026}")

        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("This deletes its 1 variable. You can\u{2019}t undo this.").exists)
    }

    @MainActor
    func testCancelKeepsTheEnvironment() {
        let screen = seededScreen()

        screen.chooseFromContextMenu(on: "Staging", "Delete\u{2026}")
        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        screen.alertButton("Cancel").click()

        XCTAssertTrue(screen.sidebarText("Staging").waitForExistence(timeout: 10))
    }

    @MainActor
    func testPickerListsNoEnvironmentAndEachEnvironmentAndNotGlobals() {
        let screen = seededScreen()
        XCTAssertEqual(screen.environmentPicker.label, "Environment")

        screen.environmentPicker.click()

        let items = screen.environmentPicker.menuItems
        XCTAssertTrue(items["No Environment"].waitForExistence(timeout: 10))
        XCTAssertTrue(items["Seeded Environment"].exists)
        XCTAssertTrue(items["Staging"].exists)
        XCTAssertFalse(items["Globals"].exists)
    }

    @MainActor
    func testPickerSelectsAnEnvironmentAndNoEnvironment() {
        let screen = seededScreen()
        XCTAssertEqual(screen.environmentPicker.value as? String, "Seeded Environment")

        screen.chooseEnvironment("Staging")
        XCTAssertTrue(screen.waitForActiveEnvironment("Staging"))

        screen.chooseEnvironment("No Environment")
        XCTAssertTrue(screen.waitForActiveEnvironment("No Environment"))
    }

    @MainActor
    func testANewEnvironmentJoinsThePicker() {
        let screen = seededScreen()

        screen.chooseFromFileMenu("New Environment")
        screen.finishRename(typing: "Production")
        XCTAssertTrue(screen.sidebarText("Production").waitForExistence(timeout: 10))

        screen.chooseEnvironment("Production")
        XCTAssertTrue(screen.waitForActiveEnvironment("Production"))
    }

    @MainActor
    func testDeletingTheActiveEnvironmentSelectsNoEnvironment() {
        let screen = seededScreen()

        screen.chooseFromContextMenu(on: "Seeded Environment", "Delete\u{2026}")
        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        screen.alertButton("Delete").click()

        XCTAssertTrue(screen.waitForRowToDisappear("Seeded Environment"))
        XCTAssertTrue(screen.waitForActiveEnvironment("No Environment"))
    }

}
