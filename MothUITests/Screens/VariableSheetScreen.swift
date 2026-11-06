//  VariableSheetScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct VariableSheetScreen {

    let app: XCUIApplication

    private var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    var doneButton: XCUIElement {
        sheet.buttons["variables.done"]
    }

    var addButton: XCUIElement {
        sheet.buttons["variables.add"]
    }

    var secureSecretField: XCUIElement {
        sheet.secureTextFields["variables.secretValue"]
    }

    var revealedSecretField: XCUIElement {
        sheet.textFields["variables.secretValue"]
    }

    var secretVisibilityButton: XCUIElement {
        sheet.buttons["variables.secretVisibility"]
    }

    var rowCount: Int {
        names.count
    }

    private var names: XCUIElementQuery {
        sheet.textFields.matching(identifier: "variables.name")
    }

    /// Any element type, because `.isHeader` on the sheet's title stops it being a static text.
    func text(_ text: String) -> XCUIElement {
        sheet.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", text, text))
            .firstMatch
    }

    func name(at row: Int) -> XCUIElement {
        names.element(boundBy: row)
    }

    func initialValue(at row: Int) -> XCUIElement {
        sheet.textFields.matching(identifier: "variables.initial").element(boundBy: row)
    }

    func currentValue(at row: Int) -> XCUIElement {
        sheet.textFields.matching(identifier: "variables.current").element(boundBy: row)
    }

    func enabledToggle(at row: Int) -> XCUIElement {
        sheet.checkBoxes.matching(identifier: "variables.enabled").element(boundBy: row)
    }

    func secretToggle(at row: Int) -> XCUIElement {
        sheet.checkBoxes.matching(identifier: "variables.secret").element(boundBy: row)
    }

    func removeButton(at row: Int) -> XCUIElement {
        sheet.buttons.matching(identifier: "variables.remove").element(boundBy: row)
    }

    func waitForRowCount(_ count: Int) -> Bool {
        let predicate = NSPredicate { _, _ in rowCount == count }
        let matched = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [matched], timeout: 10) == .completed
    }

    func waitForFocus(on field: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"),
            object: field
        )
        return XCTWaiter.wait(for: [focused], timeout: 10) == .completed
    }

    func replaceText(in field: XCUIElement, with text: String) {
        field.click()
        XCTAssertTrue(waitForFocus(on: field))
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
    }

    func close() {
        doneButton.click()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: doneButton)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed)
    }

}
