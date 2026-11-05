//  SidebarEditingTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Rows and counts mirror `SeedData` by hand: Seeded Collection > (Users > (List Users, Create User, Update User,
/// Admins > Delete Admin), Health).
final class SidebarEditingTests: MothTestCase {

    @MainActor
    private func seededScreen() -> MainWindowScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        return screen
    }

    @MainActor
    private func expandUsers(on screen: MainWindowScreen) {
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("Admins").waitForExistence(timeout: 10))
    }

    @MainActor
    func testCreatesACollectionAFolderInsideItAndARequestInsideThat() {
        let screen = seededScreen()

        screen.chooseFromFileMenu("New Collection")
        screen.finishRename(typing: "Billing")
        XCTAssertTrue(screen.sidebarText("Billing").waitForExistence(timeout: 10))

        screen.chooseFromFileMenu("New Folder")
        screen.finishRename(typing: "Invoices")
        XCTAssertTrue(screen.sidebarText("Invoices").waitForExistence(timeout: 10))

        screen.chooseFromFileMenu("New Request")
        screen.finishRename(typing: "List Invoices")
        XCTAssertTrue(screen.sidebarText("List Invoices").waitForExistence(timeout: 10))

        let collection = screen.sidebarText("Billing").frame
        let folder = screen.sidebarText("Invoices").frame
        let request = screen.sidebarText("List Invoices").frame
        XCTAssertLessThan(collection.minX, folder.minX)
        XCTAssertLessThan(folder.minX, request.minX)
        XCTAssertLessThan(collection.minY, folder.minY)
        XCTAssertLessThan(folder.minY, request.minY)
    }

    @MainActor
    func testContextMenuOffersEachRowKindItsItems() {
        let screen = seededScreen()
        expandUsers(on: screen)
        let containerItems = ["New Folder", "New Request", "Rename", "Delete\u{2026}"]

        for name in ["Seeded Collection", "Users"] {
            let menu = screen.contextMenu(on: name)
            XCTAssertTrue(menu.waitForExistence(timeout: 10))
            for item in containerItems {
                XCTAssertTrue(menu.menuItems[item].exists, "\(name) is missing \(item)")
            }
            screen.closeMenu()
        }

        let menu = screen.contextMenu(on: "List Users")
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertTrue(menu.menuItems["Rename"].exists)
        XCTAssertTrue(menu.menuItems["Delete\u{2026}"].exists)
        XCTAssertFalse(menu.menuItems["New Folder"].exists)
        XCTAssertFalse(menu.menuItems["New Request"].exists)
    }

    @MainActor
    func testFileMenuDisablesFolderAndRequestWithNothingSelected() {
        let screen = seededScreen()

        screen.openFileMenu()
        XCTAssertTrue(screen.fileMenuItem("New Collection").isEnabled)
        XCTAssertFalse(screen.fileMenuItem("New Folder").isEnabled)
        XCTAssertFalse(screen.fileMenuItem("New Request").isEnabled)
        screen.closeMenu()

        screen.select("Seeded Collection")

        screen.openFileMenu()
        XCTAssertTrue(screen.fileMenuItem("New Folder").isEnabled)
        XCTAssertTrue(screen.fileMenuItem("New Request").isEnabled)
    }

    @MainActor
    func testRowsAppearInOrderAndARequestRowShowsItsMethod() {
        let screen = seededScreen()
        expandUsers(on: screen)

        let names = ["Users", "List Users", "Create User", "Update User", "Admins", "Health"]
        let tops = names.map { screen.sidebarText($0).frame.minY }
        XCTAssertEqual(tops, tops.sorted(), "Rows are out of order: \(names) at \(tops)")

        XCTAssertTrue(screen.sidebarRow("List Users").staticTexts["GET"].exists)
        XCTAssertTrue(screen.sidebarRow("Create User").staticTexts["POST"].exists)
        XCTAssertTrue(screen.sidebarRow("Update User").staticTexts["PATCH"].exists)
    }

    @MainActor
    func testRenameChangesTheNameAndAnEmptyNameRestoresIt() {
        let screen = seededScreen()

        screen.chooseFromContextMenu(on: "Seeded Collection", "Rename")
        screen.finishRename(typing: "Renamed")
        XCTAssertTrue(screen.sidebarText("Renamed").waitForExistence(timeout: 10))

        screen.chooseFromContextMenu(on: "Renamed", "Rename")
        XCTAssertTrue(screen.renameField.waitForExistence(timeout: 10))
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        app.typeText("\n")

        XCTAssertTrue(screen.sidebarText("Renamed").waitForExistence(timeout: 10))
    }

    @MainActor
    func testDeleteAlertOnAFolderCountsItsRequestsInThePlural() {
        let screen = seededScreen()
        expandUsers(on: screen)

        screen.chooseFromContextMenu(on: "Users", "Delete\u{2026}")

        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("Delete \u{201C}Users\u{201D}?").exists)
        XCTAssertTrue(screen.alertText("This deletes its 4 requests. You can\u{2019}t undo this.").exists)
        XCTAssertTrue(screen.alertButton("Delete").exists)
        XCTAssertTrue(screen.alertButton("Cancel").exists)
    }

    @MainActor
    func testDeleteAlertOnAFolderCountsItsRequestInTheSingular() {
        let screen = seededScreen()
        expandUsers(on: screen)

        screen.chooseFromContextMenu(on: "Admins", "Delete\u{2026}")

        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("Delete \u{201C}Admins\u{201D}?").exists)
        XCTAssertTrue(screen.alertText("This deletes its 1 request. You can\u{2019}t undo this.").exists)
    }

    @MainActor
    func testDeleteAlertOnACollectionCountsEveryRequestBeneathIt() {
        let screen = seededScreen()

        screen.chooseFromContextMenu(on: "Seeded Collection", "Delete\u{2026}")

        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("Delete \u{201C}Seeded Collection\u{201D}?").exists)
        XCTAssertTrue(screen.alertText("This deletes its 5 requests. You can\u{2019}t undo this.").exists)
    }

    @MainActor
    func testDeleteAlertOnARequestMentionsNoCount() {
        let screen = seededScreen()
        expandUsers(on: screen)

        screen.chooseFromContextMenu(on: "Health", "Delete\u{2026}")

        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.alertText("Delete \u{201C}Health\u{201D}?").exists)
        XCTAssertTrue(screen.alertText("You can\u{2019}t undo this.").exists)
    }

    @MainActor
    func testCancelKeepsTheItem() {
        let screen = seededScreen()
        expandUsers(on: screen)

        screen.chooseFromContextMenu(on: "Health", "Delete\u{2026}")
        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        screen.alertButton("Cancel").click()

        XCTAssertTrue(screen.sidebarText("Health").waitForExistence(timeout: 10))
        XCTAssertFalse(screen.deleteAlert.exists)
    }

    @MainActor
    func testDeletingASelectedRequestMovesSelectionToItsParent() {
        let screen = seededScreen()
        expandUsers(on: screen)
        screen.select("List Users")

        screen.chooseFromContextMenu(on: "List Users", "Delete\u{2026}")
        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        screen.alertButton("Delete").click()

        XCTAssertTrue(screen.waitForRowToDisappear("List Users"))
        XCTAssertTrue(screen.sidebarRow("Users").isSelected)
    }

    @MainActor
    func testDeletingTheLastCollectionClearsSelectionAndBringsBackTheEmptyState() {
        let screen = seededScreen()
        screen.select("Seeded Collection")

        screen.chooseFromContextMenu(on: "Seeded Collection", "Delete\u{2026}")
        XCTAssertTrue(screen.deleteAlert.waitForExistence(timeout: 10))
        screen.alertButton("Delete").click()

        XCTAssertTrue(screen.sidebarText("No Collections").waitForExistence(timeout: 10))
        screen.openFileMenu()
        XCTAssertFalse(screen.fileMenuItem("New Folder").isEnabled)
    }

    @MainActor
    func testDraggingARequestOntoACollapsedFolderMovesItInside() {
        let screen = seededScreen()
        expandUsers(on: screen)

        screen.drag("Health", onto: "Admins")

        XCTAssertTrue(screen.waitForRowToDisappear("Health"))
        screen.expand("Admins")
        XCTAssertTrue(screen.sidebarText("Health").waitForExistence(timeout: 10))
        XCTAssertGreaterThan(screen.sidebarText("Health").frame.minX, screen.sidebarText("Admins").frame.minX)
    }

    @MainActor
    func testDraggingARequestAboveItsSiblingReordersIt() {
        let screen = seededScreen()
        expandUsers(on: screen)

        screen.drag("Update User", aboveTopOf: "List Users")

        let predicate = NSPredicate { _, _ in
            screen.sidebarText("Update User").frame.minY < screen.sidebarText("List Users").frame.minY
        }
        let reordered = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: 10), .completed)
    }

}
