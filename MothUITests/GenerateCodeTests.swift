//  GenerateCodeTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `SeedData` by hand: List Users is `{{host}}/users` with `limit=10`, and the seeded environment holds
/// `host`.
final class GenerateCodeTests: MothTestCase {

    private let copyAsCURL = "Copy as cURL"
    private let generateCode = "Generate Code\u{2026}"
    private let listUsersURL = "https://example.com/users?limit=10"

    @MainActor
    private func screens() -> (MainWindowScreen, GenerateCodeScreen) {
        (MainWindowScreen(app: app), GenerateCodeScreen(app: app))
    }

    @MainActor
    private func revealListUsers() {
        let (screen, code) = screens()
        code.clearClipboard()
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
    }

    @MainActor
    private func openListUsers() {
        revealListUsers()
        let screen = screens().0
        screen.select("List Users")
        XCTAssertTrue(screen.requestTab("GET List Users").waitForExistence(timeout: 10))
    }

    @MainActor
    func testRequestMenuItemsAreDisabledWithNoTabOpen() {
        let screen = screens().0
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))

        screen.openRequestMenu()

        XCTAssertTrue(screen.requestMenuItem(copyAsCURL).waitForExistence(timeout: 10))
        XCTAssertFalse(screen.requestMenuItem(copyAsCURL).isEnabled)
        XCTAssertFalse(screen.requestMenuItem(generateCode).isEnabled)
        screen.closeMenu()
    }

    @MainActor
    func testRequestMenuItemsAreEnabledWithATabOpen() {
        openListUsers()
        let screen = screens().0

        screen.openRequestMenu()

        XCTAssertTrue(screen.requestMenuItem(copyAsCURL).waitForExistence(timeout: 10))
        XCTAssertTrue(screen.requestMenuItem(copyAsCURL).isEnabled)
        XCTAssertTrue(screen.requestMenuItem(generateCode).isEnabled)
        screen.closeMenu()
    }

    @MainActor
    func testRequestMenuCopiesTheCurrentTabAsCURL() {
        openListUsers()
        let (screen, code) = screens()

        screen.chooseFromRequestMenu(copyAsCURL)

        XCTAssertTrue(code.waitForClipboard(containing: "curl --url '\(listUsersURL)'"))
    }

    @MainActor
    func testRequestMenuOpensGenerateCode() {
        openListUsers()
        let (screen, code) = screens()

        screen.chooseFromRequestMenu(generateCode)

        XCTAssertTrue(code.title.waitForExistence(timeout: 10))
        XCTAssertTrue(code.waitForCode(containing: listUsersURL))
    }

    @MainActor
    func testContextMenuCopiesARequestWithNoTabOpen() {
        revealListUsers()
        let (screen, code) = screens()

        screen.chooseFromContextMenu(on: "List Users", copyAsCURL)

        XCTAssertTrue(code.waitForClipboard(containing: "curl --url '\(listUsersURL)'"))
        XCTAssertFalse(screen.requestTab("GET List Users").exists)
    }

    @MainActor
    func testContextMenuOpensGenerateCode() {
        revealListUsers()
        let (screen, code) = screens()

        screen.chooseFromContextMenu(on: "List Users", generateCode)

        XCTAssertTrue(code.title.waitForExistence(timeout: 10))
        XCTAssertTrue(code.waitForCode(containing: listUsersURL))
    }

    @MainActor
    func testEscapeClosesTheSheet() {
        openListUsers()
        let (screen, code) = screens()
        screen.chooseFromRequestMenu(generateCode)
        XCTAssertTrue(code.title.waitForExistence(timeout: 10))

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(code.waitForDismissal())
    }

    @MainActor
    func testFolderContextMenuOffersNoCode() {
        revealListUsers()
        let screen = screens().0

        let menu = screen.contextMenu(on: "Users")

        XCTAssertTrue(menu.menuItems["New Request"].waitForExistence(timeout: 10))
        XCTAssertFalse(menu.menuItems[copyAsCURL].exists)
        XCTAssertFalse(menu.menuItems[generateCode].exists)
        screen.closeMenu()
    }

    @MainActor
    func testLanguagePickerAndCopy() {
        openListUsers()
        let (screen, code) = screens()
        screen.chooseFromRequestMenu(generateCode)
        XCTAssertTrue(code.title.waitForExistence(timeout: 10))
        XCTAssertTrue(code.waitForCode(containing: "curl --url"))

        code.chooseLanguage("Swift URLSession")

        XCTAssertTrue(code.waitForCode(containing: "URLRequest(url:"))

        code.copyButton.click()

        XCTAssertTrue(code.waitForClipboard(containing: "import Foundation"))

        code.chooseLanguage("cURL")
        XCTAssertTrue(code.waitForCode(containing: "curl --url"))

        code.copyButton.click()

        XCTAssertTrue(code.waitForClipboard(containing: "curl --url"))

        code.doneButton.click()

        XCTAssertTrue(code.waitForDismissal())
    }

}
