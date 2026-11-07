//  AuthorizationSheetTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Names mirror `SeedData` by hand: Seeded Collection > Users > List Users.
final class AuthorizationSheetTests: MothTestCase {

    private let authorization = "Authorization\u{2026}"

    @MainActor
    private func expandedScreen() -> MainWindowScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        return screen
    }

    @MainActor
    private func openSheet(on name: String, in screen: MainWindowScreen) -> AuthorizationSheetScreen {
        screen.chooseFromContextMenu(on: name, authorization)
        let sheet = AuthorizationSheetScreen(app: app)
        XCTAssertTrue(sheet.saveButton.waitForExistence(timeout: 10))
        return sheet
    }

    @MainActor
    func testACollectionAndAFolderOfferAuthorizationAndARequestDoesNot() {
        let screen = expandedScreen()

        let collectionMenu = screen.contextMenu(on: "Seeded Collection")
        XCTAssertTrue(collectionMenu.menuItems[authorization].waitForExistence(timeout: 10))
        screen.closeMenu()

        let folderMenu = screen.contextMenu(on: "Users")
        XCTAssertTrue(folderMenu.menuItems[authorization].waitForExistence(timeout: 10))
        screen.closeMenu()

        let requestMenu = screen.contextMenu(on: "List Users")
        XCTAssertTrue(requestMenu.menuItems["Rename"].waitForExistence(timeout: 10))
        XCTAssertFalse(requestMenu.menuItems[authorization].exists)
        screen.closeMenu()
    }

    @MainActor
    func testTheSheetOffersTheSameOptions() {
        let screen = expandedScreen()
        let sheet = openSheet(on: "Users", in: screen)

        XCTAssertEqual(sheet.fields.kindPicker.value as? String, "Inherit")

        sheet.fields.openKinds()
        for title in ["Inherit", "No Auth", "Basic Auth", "Bearer Token", "API Key", "Digest Auth", "AWS Signature"] {
            XCTAssertTrue(sheet.fields.kindMenuItem(title).waitForExistence(timeout: 10), title)
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testAFolderShowsAWSSignatureFiveFieldsAndItsButtons() {
        let screen = expandedScreen()
        let sheet = openSheet(on: "Users", in: screen)

        sheet.fields.chooseKind("AWS Signature")

        XCTAssertTrue(sheet.fields.accessKeyField.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.fields.secureSecretKeyField.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.fields.secureSessionTokenField.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.fields.regionField.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.fields.serviceField.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.saveButton.isHittable)
    }

    @MainActor
    func testSavingAFolderReachesItsRequests() {
        let screen = expandedScreen()
        let sheet = openSheet(on: "Users", in: screen)
        sheet.fields.chooseKind("Bearer Token")
        XCTAssertTrue(sheet.fields.secureTokenField.waitForExistence(timeout: 10))
        sheet.fields.secureTokenField.click()
        app.typeText("abc123")

        sheet.saveButton.click()
        XCTAssertTrue(sheet.waitToClose())

        screen.select("List Users")
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.showSection("Auth")
        XCTAssertTrue(editor.authFields.inheritedText.waitForExistence(timeout: 10))
        XCTAssertTrue(editor.waitForValue("Inherited from \u{201C}Users\u{201D}", of: editor.authFields.inheritedText))

        let reopened = openSheet(on: "Users", in: screen)
        XCTAssertEqual(reopened.fields.kindPicker.value as? String, "Bearer Token")
        XCTAssertTrue(reopened.fields.tokenVisibilityButton.waitForExistence(timeout: 10))
        reopened.fields.tokenVisibilityButton.click()
        XCTAssertTrue(reopened.fields.revealedTokenField.waitForExistence(timeout: 10))
        XCTAssertEqual(reopened.fields.revealedTokenField.value as? String, "abc123")
    }

    @MainActor
    func testSavingACollectionReachesItsRequests() {
        let screen = expandedScreen()
        let sheet = openSheet(on: "Seeded Collection", in: screen)
        XCTAssertEqual(sheet.fields.kindPicker.value as? String, "No Auth")
        sheet.fields.chooseKind("Basic Auth")
        XCTAssertTrue(sheet.fields.usernameField.waitForExistence(timeout: 10))

        sheet.saveButton.click()
        XCTAssertTrue(sheet.waitToClose())

        screen.select("List Users")
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.showSection("Auth")
        XCTAssertTrue(editor.authFields.inheritedText.waitForExistence(timeout: 10))
        XCTAssertTrue(
            editor.waitForValue("Inherited from \u{201C}Seeded Collection\u{201D}", of: editor.authFields.inheritedText)
        )
    }

    @MainActor
    func testCancelLeavesTheAuthAsItWas() {
        let screen = expandedScreen()
        let sheet = openSheet(on: "Users", in: screen)
        sheet.fields.chooseKind("Bearer Token")
        XCTAssertTrue(sheet.fields.secureTokenField.waitForExistence(timeout: 10))

        sheet.cancelButton.click()
        XCTAssertTrue(sheet.waitToClose())

        let reopened = openSheet(on: "Users", in: screen)
        XCTAssertEqual(reopened.fields.kindPicker.value as? String, "Inherit")
    }

}
