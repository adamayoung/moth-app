//  AuthFieldsScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// The same fields sit in the editor pane and the Authorization sheet, so this takes the element that holds them.
@MainActor
struct AuthFieldsScreen {

    let root: XCUIElement

    var kindPicker: XCUIElement {
        root.popUpButtons["auth.kind"]
    }

    var usernameField: XCUIElement {
        root.textFields["auth.username"]
    }

    var securePasswordField: XCUIElement {
        root.secureTextFields["auth.password"]
    }

    var secureTokenField: XCUIElement {
        root.secureTextFields["auth.token"]
    }

    var revealedTokenField: XCUIElement {
        root.textFields["auth.token"]
    }

    var tokenVisibilityButton: XCUIElement {
        root.buttons["auth.tokenVisibility"]
    }

    var passwordVisibilityButton: XCUIElement {
        root.buttons["auth.passwordVisibility"]
    }

    var apiKeyNameField: XCUIElement {
        root.textFields["auth.apiKeyName"]
    }

    var secureAPIKeyValueField: XCUIElement {
        root.secureTextFields["auth.apiKeyValue"]
    }

    var apiKeyLocationPicker: XCUIElement {
        root.popUpButtons["auth.apiKeyLocation"]
    }

    var accessKeyField: XCUIElement {
        root.textFields["auth.accessKey"]
    }

    var secureSecretKeyField: XCUIElement {
        root.secureTextFields["auth.secretKey"]
    }

    var secureSessionTokenField: XCUIElement {
        root.secureTextFields["auth.sessionToken"]
    }

    var regionField: XCUIElement {
        root.textFields["auth.region"]
    }

    var serviceField: XCUIElement {
        root.textFields["auth.service"]
    }

    var inheritedText: XCUIElement {
        root.staticTexts["auth.inherited"]
    }

    var notSupportedText: XCUIElement {
        root.staticTexts["auth.notSupported"]
    }

    func openKinds() {
        kindPicker.click()
    }

    func kindMenuItem(_ title: String) -> XCUIElement {
        kindPicker.menuItems[title]
    }

    func chooseKind(_ title: String) {
        openKinds()
        kindMenuItem(title).click()
    }

}
