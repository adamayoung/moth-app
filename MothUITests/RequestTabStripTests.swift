//  RequestTabStripTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Names and methods mirror `SeedData` by hand: Users > (GET List Users, POST Create User, PATCH Update User).
final class RequestTabStripTests: MothTestCase {

    @MainActor
    private func screenWithUsersExpanded() -> MainWindowScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        return screen
    }

    @MainActor
    private func open(_ name: String, showing tab: String, on screen: MainWindowScreen) {
        screen.select(name)
        XCTAssertTrue(screen.requestTab(tab).waitForExistence(timeout: 10))
    }

    @MainActor
    func testOpeningTwoRequestsShowsTwoTabs() {
        let screen = screenWithUsersExpanded()

        open("List Users", showing: "GET List Users", on: screen)
        open("Create User", showing: "POST Create User", on: screen)

        XCTAssertEqual(screen.requestTabs.count, 2)
        XCTAssertTrue(screen.requestTab("POST Create User").isSelected)
        XCTAssertFalse(screen.requestTab("GET List Users").isSelected)
        XCTAssertTrue(screen.requestEditorText("Create User").exists)
    }

    @MainActor
    func testClickingTheTopEdgeOfARowOpensTheRequest() {
        let screen = screenWithUsersExpanded()

        screen.sidebarRow("List Users").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)).click()

        XCTAssertTrue(screen.requestTab("GET List Users").waitForExistence(timeout: 10))
    }

    @MainActor
    func testReturnOpensTheSelectedRequest() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        screen.closeTabKey()
        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))

        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(screen.requestTab("GET List Users").waitForExistence(timeout: 10))
    }

    @MainActor
    func testClickTargetsFillTheTab() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)

        let select = screen.requestTab("GET List Users").frame
        let close = screen.requestTabCloseButton("Close List Users").frame

        XCTAssertGreaterThanOrEqual(select.height, 28)
        XCTAssertGreaterThanOrEqual(close.height, 28)
        XCTAssertGreaterThanOrEqual(close.width, 20)
    }

    @MainActor
    func testCommandWWithTheDeleteAlertUpLeavesTheTabOpen() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        screen.chooseFromContextMenu(on: "List Users", "Delete\u{2026}")
        XCTAssertTrue(screen.alertButton("Cancel").waitForExistence(timeout: 10))

        screen.closeTabKey()
        screen.alertButton("Cancel").click()

        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        XCTAssertTrue(screen.requestTab("GET List Users").exists)
    }

    @MainActor
    func testClickingAnOpenRequestSelectsItsTab() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        open("Create User", showing: "POST Create User", on: screen)

        screen.select("List Users")

        XCTAssertTrue(screen.requestEditorText("List Users").waitForExistence(timeout: 10))
        XCTAssertEqual(screen.requestTabs.count, 2)
    }

    @MainActor
    func testClickingAnOpenRequestSelectsItsTabAfterTheStripSelectedAnother() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        open("Create User", showing: "POST Create User", on: screen)
        screen.requestTab("GET List Users").click()
        XCTAssertTrue(screen.requestEditorText("List Users").waitForExistence(timeout: 10))

        screen.select("Create User")

        XCTAssertTrue(screen.requestEditorText("Create User").waitForExistence(timeout: 10))
        XCTAssertEqual(screen.requestTabs.count, 2)
    }

    @MainActor
    func testClickingATabSelectsIt() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        open("Create User", showing: "POST Create User", on: screen)

        screen.requestTab("GET List Users").click()

        XCTAssertTrue(screen.requestEditorText("List Users").waitForExistence(timeout: 10))
        XCTAssertTrue(screen.requestTab("GET List Users").isSelected)
    }

    @MainActor
    func testClickingARequestStillSelectedAfterItsTabClosedOpensItAgain() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        screen.closeTabKey()
        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))

        screen.select("List Users")

        XCTAssertTrue(screen.requestTab("GET List Users").waitForExistence(timeout: 10))
    }

    @MainActor
    func testRenameUpdatesTheTab() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)

        screen.chooseFromContextMenu(on: "List Users", "Rename")
        screen.finishRename(typing: "All Users")

        XCTAssertTrue(screen.requestTab("GET All Users").waitForExistence(timeout: 10))
        XCTAssertTrue(screen.requestEditorText("All Users").waitForExistence(timeout: 10))
        XCTAssertEqual(screen.requestTabs.count, 1)
    }

    @MainActor
    func testCommandWClosesATabAndTheLastCloseShowsTheEmptyState() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        open("Create User", showing: "POST Create User", on: screen)

        screen.closeTabKey()
        XCTAssertTrue(screen.waitForTabToClose("POST Create User"))
        XCTAssertTrue(screen.requestEditorText("List Users").waitForExistence(timeout: 10))

        screen.closeTabKey()
        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))
        XCTAssertTrue(screen.requestEditorText("No Request Open").waitForExistence(timeout: 10))
        XCTAssertEqual(app.windows.count, 1)
    }

    @MainActor
    func testFileMenuClosesTheSelectedTab() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)

        screen.chooseFromFileMenu("Close Tab")

        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))
        XCTAssertEqual(app.windows.count, 1)
    }

    @MainActor
    func testFileMenuNamesWhatCommandWCloses() {
        let screen = screenWithUsersExpanded()

        screen.openFileMenu()
        XCTAssertTrue(screen.fileMenuItem("Close").exists)
        XCTAssertFalse(screen.fileMenuItem("Close Tab").exists)
        XCTAssertTrue(screen.fileMenuItem("Close Window").exists)
        screen.closeMenu()

        open("List Users", showing: "GET List Users", on: screen)

        screen.openFileMenu()
        XCTAssertTrue(screen.fileMenuItem("Close Tab").exists)
        XCTAssertFalse(screen.fileMenuItem("Close").exists)
        XCTAssertTrue(screen.fileMenuItem("Close Window").exists)
        screen.closeMenu()
    }

    @MainActor
    func testATabsCloseButtonClosesIt() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)
        open("Create User", showing: "POST Create User", on: screen)

        screen.requestTabCloseButton("Close List Users").click()

        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))
        XCTAssertTrue(screen.requestTab("POST Create User").isSelected)
    }

    @MainActor
    func testDeletingARequestClosesItsTab() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)

        screen.chooseFromContextMenu(on: "List Users", "Delete\u{2026}")
        XCTAssertTrue(screen.alertButton("Delete").waitForExistence(timeout: 10))
        screen.alertButton("Delete").click()

        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))
        XCTAssertTrue(screen.requestEditorText("No Request Open").waitForExistence(timeout: 10))
    }

    @MainActor
    func testCommandWWithNoTabsClosesTheWindow() {
        let screen = screenWithUsersExpanded()

        screen.closeTabKey()

        XCTAssertTrue(screen.waitForEveryWindowToClose())
    }

    @MainActor
    func testShiftCommandWClosesTheWindowWithTabsOpen() {
        let screen = screenWithUsersExpanded()
        open("List Users", showing: "GET List Users", on: screen)

        screen.closeWindowKey()

        XCTAssertTrue(screen.waitForEveryWindowToClose())
    }

}
