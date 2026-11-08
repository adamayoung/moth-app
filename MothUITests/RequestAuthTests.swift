//  RequestAuthTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `SeedData` by hand: List Users inherits, with nothing above it that sets auth, Health has API key
/// auth, Update User has Digest auth and Delete Admin, in Users > Admins, has OAuth 2.0 with the Implicit grant. The
/// `/token` paths are `StubHTTPTransport`'s token endpoints.
final class RequestAuthTests: MothTestCase {

    @MainActor
    private func openAuth(
        of name: String,
        in folders: [String] = ["Users"]
    ) -> (MainWindowScreen, RequestEditorScreen, AuthFieldsScreen) {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        for folder in folders {
            XCTAssertTrue(screen.sidebarText(folder).waitForExistence(timeout: 10))
            screen.expand(folder)
        }
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
    func testAuthOffersEveryKindItCanEdit() {
        let (_, _, fields) = openAuth(of: "List Users")

        XCTAssertEqual(fields.kindPicker.value as? String, "Inherit")

        fields.openKinds()
        let titles = [
            "Inherit", "No Auth", "Basic Auth", "Bearer Token", "API Key", "Digest Auth", "OAuth 2.0", "AWS Signature"
        ]
        for title in titles {
            XCTAssertTrue(fields.kindMenuItem(title).waitForExistence(timeout: 10), title)
        }
        XCTAssertEqual(fields.kindPicker.menuItems.count, 8)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testAWSSignatureShowsItsFiveFields() {
        let (_, _, fields) = openAuth(of: "List Users")

        fields.chooseKind("AWS Signature")

        XCTAssertTrue(fields.accessKeyField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.secureSecretKeyField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.secureSessionTokenField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.regionField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.serviceField.waitForExistence(timeout: 10))
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

        fields.chooseKind("Digest Auth")
        XCTAssertTrue(fields.usernameField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.securePasswordField.waitForExistence(timeout: 10))
        XCTAssertFalse(fields.secureTokenField.exists)
        XCTAssertFalse(fields.notSupportedText.exists)

        fields.chooseKind("API Key")
        XCTAssertTrue(fields.apiKeyNameField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.secureAPIKeyValueField.waitForExistence(timeout: 10))
        XCTAssertTrue(fields.apiKeyLocationPicker.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.apiKeyLocationPicker.value as? String, "Header")
        XCTAssertFalse(fields.secureTokenField.exists)

        fields.chooseKind("No Auth")
        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("No Auth", of: fields.kindPicker))
        XCTAssertFalse(fields.apiKeyNameField.exists)
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
    func testAnImportedGrantMothCantRunShowsNotSupported() {
        let (screen, _, fields) = openAuth(of: "Delete Admin", in: ["Users", "Admins"])

        XCTAssertEqual(fields.kindPicker.value as? String, "OAuth 2.0")
        XCTAssertTrue(fields.grantTypePicker.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.grantTypePicker.value as? String, "Implicit")
        XCTAssertTrue(fields.notSupportedText.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.notSupportedText.value as? String, "Not Supported Yet")
        XCTAssertFalse(fields.tokenURLField.exists)
        XCTAssertFalse(screen.editedDot(on: "Delete Admin").exists)

        fields.grantTypePicker.click()
        XCTAssertTrue(fields.grantTypePicker.menuItems["Client Credentials"].waitForExistence(timeout: 10))
        XCTAssertTrue(fields.grantTypePicker.menuItems["Implicit"].exists)
        fields.grantTypePicker.menuItems["Client Credentials"].click()

        XCTAssertTrue(fields.tokenURLField.waitForExistence(timeout: 10))
        XCTAssertFalse(fields.notSupportedText.exists)
    }

    @MainActor
    func testOAuth2ShowsItsFields() {
        let (_, _, fields) = openAuth(of: "List Users")

        fields.chooseKind("OAuth 2.0")

        XCTAssertTrue(fields.grantTypePicker.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.grantTypePicker.value as? String, "Client Credentials")
        XCTAssertTrue(fields.tokenURLField.exists)
        XCTAssertTrue(fields.clientIDField.exists)
        XCTAssertTrue(fields.secureClientSecretField.exists)
        XCTAssertTrue(fields.scopeField.exists)
        XCTAssertTrue(fields.getNewTokenButton.exists)
        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("No Token", of: fields.tokenStateText))
        XCTAssertFalse(fields.clearTokenButton.isEnabled)
        XCTAssertFalse(fields.notSupportedText.exists)
    }

    @MainActor
    func testAuthorizationCodeShowsItsFieldsAndTheDefaultCallbackURL() {
        let (_, _, fields) = openAuth(of: "List Users")
        fields.chooseKind("OAuth 2.0")
        XCTAssertTrue(fields.grantTypePicker.waitForExistence(timeout: 10))

        fields.grantTypePicker.click()
        XCTAssertTrue(fields.grantTypePicker.menuItems["Authorization Code (With PKCE)"].waitForExistence(timeout: 10))
        fields.grantTypePicker.menuItems["Authorization Code (With PKCE)"].click()

        XCTAssertTrue(fields.authURLField.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.callbackURLField.value as? String, "moth://oauth/callback")
        XCTAssertFalse(fields.callbackURLProblemText.exists)
        XCTAssertTrue(fields.tokenURLField.exists)
        XCTAssertTrue(fields.clientIDField.exists)
        XCTAssertEqual(fields.secureClientSecretField.placeholderValue, "Optional")
        XCTAssertTrue(fields.scopeField.exists)
        XCTAssertTrue(fields.getNewTokenButton.exists)
        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("No Token", of: fields.tokenStateText))

        fields.callbackURLField.click()
        fields.callbackURLField.typeKey("a", modifierFlags: .command)
        app.typeText("https://example.com/callback")
        XCTAssertTrue(fields.callbackURLProblemText.waitForExistence(timeout: 10))
        XCTAssertEqual(
            fields.callbackURLProblemText.value as? String,
            "Moth can only receive a sign-in at a custom URL scheme."
        )
    }

    @MainActor
    private func getToken(from path: String) -> AuthFieldsScreen {
        let (_, _, fields) = openAuth(of: "List Users")
        fields.chooseKind("OAuth 2.0")
        XCTAssertTrue(fields.tokenURLField.waitForExistence(timeout: 10))
        fields.tokenURLField.click()
        app.typeText("https://example.com\(path)")
        fields.clientIDField.click()
        app.typeText("moth")
        fields.getNewTokenButton.click()
        return fields
    }

    @MainActor
    func testGetNewAccessTokenShowsWhenItExpiresAndClearTokenRemovesIt() {
        let fields = getToken(from: "/token")

        XCTAssertTrue(fields.waitForTokenState(beginningWith: "Expires in"))
        XCTAssertTrue(fields.clearTokenButton.isEnabled)

        fields.clearTokenButton.click()

        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("No Token", of: fields.tokenStateText))
    }

    @MainActor
    func testATokenPastItsExpiryShowsTokenExpired() {
        let fields = getToken(from: "/token/expired")

        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("Token Expired", of: fields.tokenStateText))
    }

    @MainActor
    func testATokenWithNoExpiryShowsItDoesNotExpire() {
        let fields = getToken(from: "/token/forever")

        XCTAssertTrue(RequestEditorScreen(app: app).waitForValue("Doesn\u{2019}t Expire", of: fields.tokenStateText))
    }

    @MainActor
    func testARefusedTokenRequestShowsTheServersError() {
        let fields = getToken(from: "/token/refused")

        XCTAssertTrue(fields.tokenFailureText.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.tokenFailureText.value as? String, "Couldn\u{2019}t Get Access Token")
        XCTAssertEqual(
            fields.tokenFailureReasonText.value as? String,
            "invalid_client: Client authentication failed."
        )
        XCTAssertEqual(fields.tokenStateText.value as? String, "No Token")
    }

    @MainActor
    func testAStoredDigestShowsItsFields() {
        let (screen, _, fields) = openAuth(of: "Update User")

        XCTAssertEqual(fields.kindPicker.value as? String, "Digest Auth")
        XCTAssertTrue(fields.usernameField.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.usernameField.value as? String, "ada")
        XCTAssertTrue(fields.securePasswordField.exists)
        XCTAssertFalse(fields.notSupportedText.exists)
        XCTAssertFalse(screen.editedDot(on: "Update User").exists)
    }

    @MainActor
    func testAStoredAPIKeyShowsItsFields() {
        let (screen, _, fields) = openAuth(of: "Health")

        XCTAssertEqual(fields.kindPicker.value as? String, "API Key")
        XCTAssertTrue(fields.apiKeyNameField.waitForExistence(timeout: 10))
        XCTAssertEqual(fields.apiKeyNameField.value as? String, "X-Key")
        XCTAssertEqual(fields.apiKeyLocationPicker.value as? String, "Header")
        XCTAssertFalse(fields.notSupportedText.exists)
        XCTAssertFalse(screen.editedDot(on: "Health").exists)
    }

    @MainActor
    func testAddToOffersHeaderAndQueryParams() {
        let (_, editor, fields) = openAuth(of: "List Users")
        fields.chooseKind("API Key")
        XCTAssertTrue(fields.apiKeyLocationPicker.waitForExistence(timeout: 10))

        fields.apiKeyLocationPicker.click()
        XCTAssertTrue(fields.apiKeyLocationPicker.menuItems["Header"].waitForExistence(timeout: 10))
        fields.apiKeyLocationPicker.menuItems["Query Params"].click()

        XCTAssertTrue(editor.waitForValue("Query Params", of: fields.apiKeyLocationPicker))
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
