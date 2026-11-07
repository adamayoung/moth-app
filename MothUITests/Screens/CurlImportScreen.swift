//  CurlImportScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct CurlImportScreen {

    let app: XCUIApplication

    var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    var title: XCUIElement {
        sheet.staticTexts["Import cURL"]
    }

    var textArea: XCUIElement {
        sheet.textViews["curlImport.text"]
    }

    var importButton: XCUIElement {
        sheet.buttons["curlImport.import"]
    }

    var cancelButton: XCUIElement {
        sheet.buttons["curlImport.cancel"]
    }

    var problem: XCUIElement {
        sheet.staticTexts["curlImport.problem"]
    }

    func type(_ text: String) {
        textArea.click()
        app.typeText(text)
    }

}
