//  CookiesSheetScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct CookiesSheetScreen {

    let app: XCUIApplication

    var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    var title: XCUIElement {
        sheet.staticTexts["Cookies"]
    }

    var value: XCUIElement {
        sheet.staticTexts["cookies.value"]
    }

    var deleteButton: XCUIElement {
        sheet.buttons["cookies.delete"]
    }

    var deleteAllButton: XCUIElement {
        sheet.buttons["cookies.deleteAll"]
    }

    var doneButton: XCUIElement {
        sheet.buttons["cookies.done"]
    }

    func deleteDomainButton(_ domain: String) -> XCUIElement {
        sheet.buttons["cookies.deleteDomain.\(domain)"]
    }

    func text(_ text: String) -> XCUIElement {
        sheet.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    /// The Delete All alert sits on the sheet, so its text and buttons are found from the app.
    func alertText(_ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    func alertButton(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    func waitForDisappearance(of element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: 10) == .completed
    }

}
