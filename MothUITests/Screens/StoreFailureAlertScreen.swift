//  StoreFailureAlertScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct StoreFailureAlertScreen {

    let app: XCUIApplication

    var alert: XCUIElement {
        app.dialogs.firstMatch
    }

    var buttons: XCUIElementQuery {
        alert.buttons
    }

    var quitButton: XCUIElement {
        buttons["Quit"]
    }

    func text(_ text: String) -> XCUIElement {
        alert.staticTexts[text]
    }

}
