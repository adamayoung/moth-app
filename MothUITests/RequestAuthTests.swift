//  RequestAuthTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `SeedData` by hand: List Users inherits, with nothing above it that sets auth, and Health has API key
/// auth.
final class RequestAuthTests: MothTestCase {

    @MainActor
    private func openAuth(of name: String) -> (MainWindowScreen, RequestEditorScreen, AuthFieldsScreen) {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText(name).waitForExistence(timeout: 10))
        screen.select(name)
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.showSection("Auth")
        let fields = editor.authFields
        XCTAssertTrue(fields.kindPicker.waitForExistence(timeout: 10))
        return (screen, editor, fields)
    }

    @MainActor
    func testAuthOffersInheritNoAuthBasicAndBearer() {
        let (_, _, fields) = openAuth(of: "List Users")

        XCTAssertEqual(fields.kindPicker.value as? String, "Inherit")

        fields.openKinds()
        for title in ["Inherit", "No Auth", "Basic Auth", "Bearer Token"] {
            XCTAssertTrue(fields.kindMenuItem(title).waitForExistence(timeout: 10), title)
        }
        XCTAssertEqual(fields.kindPicker.menuItems.count, 4)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testInheritSaysThereIsNothingToInherit() {
        let (_, _, fields) = openAuth(of: "List Users")

        XCTAssertTrue(fields.inheritedText.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.inheritedText.value as? String, "No auth to inherit")
    }

    @MainActor
    func testEachAuthOptionShowsItsFields() {
        let (_, _, fields) = openAuth(of: "List Users")

        fields.chooseKind("Basic Auth")
        XCTAssertTrue(fields.usernameField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.securePasswordField.waitForExistence(timeout: 10))
        XCTAssertFalse(fields.inheritedText.exists)
        XCTAssertFalse(fields.secureTokenField.exists)

        fields.chooseKind("Bearer Token")
        XCTAssertTrue(fields.secureTokenField.waitForExistence(timeout: 10))
        XCTAssertFalse(fields.usernameField.exists)
        XCTAssertFalse(fields.securePasswordField.exists)

        fields.chooseKind("No Auth")
        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("No Auth", of: fields.kindPicker))
        XCTAssertFalse(fields.secureTokenField.exists)
        XCTAssertFalse(fields.inheritedText.exists)

        fields.chooseKind("Inherit")
        XCTAssertTrue(fields.inheritedText.waitForExistence(timeout: 10))
    }

    @MainActor
    func testShowAndHideRevealAndConcealAToken() {
        let (_, _, fields) = openAuth(of: "List Users")
        fields.chooseKind("Bearer Token")
        XCTAssertTrue(fields.secureTokenField.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.tokenVisibilityButton.label, "Show")
        fields.secureTokenField.click()
        app.typeText("abc123")

        fields.tokenVisibilityButton.click()

        XCTAssertTrue(fields.revealedTokenField.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.revealedTokenField.value as? String, "abc123")
        XCTAssertFalse(fields.secureTokenField.exists)
        XCTAssertEqual(fields.tokenVisibilityButton.label, "Hide")

        fields.tokenVisibilityButton.click()

        XCTAssertTrue(fields.secureTokenField.waitForExistence(timeout: 10))
        XCTAssertFalse(fields.revealedTokenField.exists)
    }

    @MainActor
    func testShowRevealsAPassword() {
        let (_, _, fields) = openAuth(of: "List Users")
        fields.chooseKind("Basic Auth")
        XCTAssertTrue(fields.securePasswordField.waitForExistence(timeout: 10))

        fields.passwordVisibilityButton.click()

        XCTAssertTrue(fields.passwordVisibilityButton.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.passwordVisibilityButton.label, "Hide")
        XCTAssertFalse(fields.securePasswordField.exists)
    }

    @MainActor
    func testAnAuthMothCantEditShowsNotSupported() {
        let (screen, _, fields) = openAuth(of: "Health")

        XCTAssertEqual(fields.kindPicker.value as? String, "API Key")
        XCTAssertTrue(fields.notSupportedText.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.notSupportedText.value as? String, "Not Supported Yet")
        XCTAssertFalse(screen.editedDot(on: "Health").exists)
    }

    @MainActor
    func testAnAuthEditShowsTheDotAndSaveKeepsTheCredential() {
        let (screen, editor, fields) = openAuth(of: "List Users")
        fields.chooseKind("Bearer Token")
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))
        XCTAssertTrue(fields.secureTokenField.waitForExistence(timeout: 10))
        fields.secureTokenField.click()
        app.typeText("abc123")

        screen.saveKey()
        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))

        screen.select("Create User")
        XCTAssertTrue(screen.requestTab("POST Create User").waitForExistence(timeout: 10))
        screen.requestTab("GET List Users").click()
        XCTAssertTrue(fields.tokenVisibilityButton.waitForExistence(timeout: 10))
        fields.tokenVisibilityButton.click()

        XCTAssertTrue(fields.revealedTokenField.waitForExistence(timeout: 10))
        XCTAssertTrue(editor.waitForValue("abc123", of: fields.revealedTokenField))
        XCTAssertFalse(screen.editedDot(on: "List Users").exists)
    }

}
