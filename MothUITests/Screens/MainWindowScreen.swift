//  MainWindowScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct MainWindowScreen {

    let app: XCUIApplication

    var window: XCUIElement {
        app.windows.firstMatch
    }

    var toolbar: XCUIElement {
        window.toolbars.firstMatch
    }

    var sidebar: XCUIElement {
        window.outlines["sidebar"]
    }

    var tabStrip: XCUIElement {
        region("tabStrip")
    }

    var requestEditorPane: XCUIElement {
        region("requestEditorPane")
    }

    var responsePane: XCUIElement {
        region("responsePane")
    }

    func sidebarText(_ text: String) -> XCUIElement {
        sidebar.staticTexts[text]
    }

    func requestEditorText(_ text: String) -> XCUIElement {
        requestEditorPane.staticTexts[text]
    }

    func responseText(_ text: String) -> XCUIElement {
        responsePane.staticTexts[text]
    }

    private func region(_ identifier: String) -> XCUIElement {
        window.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

}
