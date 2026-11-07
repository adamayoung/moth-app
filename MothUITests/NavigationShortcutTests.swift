//  NavigationShortcutTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Rows mirror `SeedData` by hand: Seeded Collection > (Users > (GET List Users, POST Create User, PATCH Update User,
/// Admins), GET Health), and List Users' URL is `{{host}}/users?limit=10`.
final class NavigationShortcutTests: MothTestCase {

    @MainActor
    private func seededScreen() -> MainWindowScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        return screen
    }

    @MainActor
    private func screenWithUsersExpanded() -> MainWindowScreen {
        let screen = seededScreen()
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        return screen
    }

    @MainActor
    private func createRequestWithKey(named name: String, on screen: MainWindowScreen) {
        screen.newRequestKey()
        XCTAssertTrue(screen.requestTab("GET New Request").waitForExistence(timeout: 10))
        screen.finishRename(typing: name)
        XCTAssertTrue(screen.sidebarText(name).waitForExistence(timeout: 10))
        XCTAssertTrue(screen.requestTab("GET \(name)").waitForExistence(timeout: 10))
    }

    @MainActor
    func testCommandTAddsARequestToTheSelectedFolder() {
        let screen = screenWithUsersExpanded()
        screen.select("Users")

        createRequestWithKey(named: "Search Users", on: screen)

        let folder = screen.sidebarText("Users").frame
        let request = screen.sidebarText("Search Users").frame
        XCTAssertEqual(request.minX, screen.sidebarText("List Users").frame.minX, accuracy: 1)
        XCTAssertGreaterThan(request.minX, folder.minX)
        XCTAssertLessThan(request.minY, screen.sidebarText("Health").frame.minY)
    }

    @MainActor
    func testCommandTAddsARequestBesideTheSelectedRequest() {
        let screen = screenWithUsersExpanded()
        screen.select("Health")

        createRequestWithKey(named: "Status", on: screen)

        XCTAssertEqual(screen.sidebarText("Status").frame.minX, screen.sidebarText("Health").frame.minX, accuracy: 1)
    }

    @MainActor
    func testCommandTWithNothingSelectedAddsARequestToTheFirstCollection() {
        let screen = seededScreen()

        createRequestWithKey(named: "Ping", on: screen)

        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        XCTAssertEqual(screen.sidebarText("Ping").frame.minX, screen.sidebarText("Users").frame.minX, accuracy: 1)
    }

    @MainActor
    func testNewRequestIsDisabledWithNoCollection() {
        let screen = seededScreen()
        screen.chooseFromContextMenu(on: "Seeded Collection", "Delete\u{2026}")
        XCTAssertTrue(screen.alertButton("Delete").waitForExistence(timeout: 10))
        screen.alertButton("Delete").click()
        XCTAssertTrue(screen.waitForRowToDisappear("Seeded Collection"))

        screen.openFileMenu()

        XCTAssertTrue(screen.fileMenuItem("New Request").waitForExistence(timeout: 10))
        XCTAssertFalse(screen.fileMenuItem("New Request").isEnabled)
    }

    @MainActor
    func testCommandLSelectsTheURLWhereverFocusIs() {
        let screen = screenWithUsersExpanded()
        let editor = RequestEditorScreen(app: app)
        screen.select("List Users")
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))

        screen.editURLKey()
        app.typeText("https://example.com")
        XCTAssertTrue(editor.waitForValue("https://example.com", of: editor.urlField))

        editor.urlField.click()
        app.typeKey(.leftArrow, modifierFlags: [])
        screen.editURLKey()
        app.typeText("{{host}}")
        XCTAssertTrue(editor.waitForValue("{{host}}", of: editor.urlField))
    }

    @MainActor
    func testControlTabMovesBetweenTabsAndWraps() {
        let screen = screenWithUsersExpanded()
        openThreeTabs(on: screen)
        RequestEditorScreen(app: app).urlField.click()

        screen.nextTabKey()
        XCTAssertTrue(screen.waitForSelectedTab("GET List Users"))
        screen.nextTabKey()
        XCTAssertTrue(screen.waitForSelectedTab("POST Create User"))

        screen.previousTabKey()
        XCTAssertTrue(screen.waitForSelectedTab("GET List Users"))
        screen.previousTabKey()
        XCTAssertTrue(screen.waitForSelectedTab("PATCH Update User"))
    }

    @MainActor
    func testCommandShiftBracketsMoveBetweenTabsAndWrap() {
        let screen = screenWithUsersExpanded()
        openThreeTabs(on: screen)

        screen.nextTabBracketKey()
        XCTAssertTrue(screen.waitForSelectedTab("GET List Users"))

        screen.previousTabBracketKey()
        XCTAssertTrue(screen.waitForSelectedTab("PATCH Update User"))
        screen.previousTabBracketKey()
        XCTAssertTrue(screen.waitForSelectedTab("POST Create User"))
    }

    @MainActor
    private func openThreeTabs(on screen: MainWindowScreen) {
        for (name, tab) in [
            ("List Users", "GET List Users"),
            ("Create User", "POST Create User"),
            ("Update User", "PATCH Update User")
        ] {
            screen.select(name)
            XCTAssertTrue(screen.requestTab(tab).waitForExistence(timeout: 10))
        }
        XCTAssertTrue(screen.waitForSelectedTab("PATCH Update User"))
    }

}
