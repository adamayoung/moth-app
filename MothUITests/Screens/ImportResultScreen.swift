//  ImportResultScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct ImportResultScreen {

    let app: XCUIApplication

    var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    var skippedText: XCUIElement {
        sheet.staticTexts["importResult.skipped"]
    }

    var doneButton: XCUIElement {
        sheet.buttons["importResult.done"]
    }

    func text(_ text: String) -> XCUIElement {
        sheet.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    func waitForDismissal() -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        return XCTWaiter.wait(for: [gone], timeout: 10) == .completed
    }

}
