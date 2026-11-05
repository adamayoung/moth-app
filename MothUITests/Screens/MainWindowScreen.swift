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
        app.outlines["sidebar"]
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

    private func region(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

}
