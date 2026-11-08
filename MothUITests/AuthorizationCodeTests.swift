//  AuthorizationCodeTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// The OAuth 2.0 Authorization Code grant's pane, on List Users, in Users, which `SeedData` leaves inheriting. The
/// system sign-in sheet can't be driven here, so these stop short of Get New Access Token.
final class AuthorizationCodeTests: MothTestCase {

    @MainActor
    private func openAuthorizationCode() -> AuthFieldsScreen {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        screen.select("List Users")
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.showSection("Auth")
        let fields = editor.authFields
        XCTAssertTrue(fields.kindPicker.waitForExistence(timeout: 10))
        fields.chooseKind("OAuth 2.0")
        XCTAssertTrue(fields.grantTypePicker.waitForExistence(timeout: 10))
        fields.grantTypePicker.click()
        XCTAssertTrue(fields.grantTypePicker.menuItems["Authorization Code (With PKCE)"].waitForExistence(timeout: 10))
        fields.grantTypePicker.menuItems["Authorization Code (With PKCE)"].click()
        XCTAssertTrue(fields.authURLField.waitForExistence(timeout: 10))
        return fields
    }

    @MainActor
    func testAuthorizationCodeShowsItsFieldsAndTheDefaultCallbackURL() {
        let fields = openAuthorizationCode()

        XCTAssertEqual(fields.callbackURLField.value as? String, "moth://oauth/callback")
        XCTAssertFalse(fields.callbackURLProblemText.exists)
        XCTAssertTrue(fields.tokenURLField.exists)
        XCTAssertTrue(fields.clientIDField.exists)
        XCTAssertEqual(fields.secureClientSecretField.placeholderValue, "Optional")
        XCTAssertTrue(fields.scopeField.exists)
        XCTAssertTrue(fields.getNewTokenButton.exists)
        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("No Token", of: fields.tokenStateText))
    }

    @MainActor
    func testAWebCallbackURLSaysMothCanOnlyReceiveACustomScheme() {
        let fields = openAuthorizationCode()

        fields.callbackURLField.click()
        fields.callbackURLField.typeKey("a", modifierFlags: .command)
        app.typeText("https://example.com/callback")

        XCTAssertTrue(fields.callbackURLProblemText.waitForExistence(timeout: 10))
        XCTAssertEqual(
            fields.callbackURLProblemText.value as? String,
            "Moth can only receive a sign-in at a custom URL scheme."
        )
    }

}
