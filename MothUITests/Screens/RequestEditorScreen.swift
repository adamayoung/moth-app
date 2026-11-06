//  RequestEditorScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct RequestEditorScreen {

    let app: XCUIApplication

    private var pane: XCUIElement {
        app.windows.firstMatch.descendants(matching: .any).matching(identifier: "requestEditorPane").firstMatch
    }

    var methodPicker: XCUIElement {
        pane.popUpButtons["requestEditor.method"]
    }

    var urlField: XCUIElement {
        pane.textFields["requestEditor.url"]
    }

    func showSection(_ title: String) {
        pane.radioButtons[title].click()
    }

    func keyField(_ section: String, at row: Int) -> XCUIElement {
        pane.textFields.matching(identifier: "\(section).key").element(boundBy: row)
    }

    func valueField(_ section: String, at row: Int) -> XCUIElement {
        pane.textFields.matching(identifier: "\(section).value").element(boundBy: row)
    }

    func enabledCheckbox(_ section: String, at row: Int) -> XCUIElement {
        pane.checkBoxes.matching(identifier: "\(section).enabled").element(boundBy: row)
    }

    func rowCount(_ section: String) -> Int {
        pane.textFields.matching(identifier: "\(section).key").count
    }

    func addRow(_ section: String) {
        pane.buttons["\(section).add"].click()
    }

    func removeRow(_ section: String, at row: Int) {
        pane.buttons.matching(identifier: "\(section).remove").element(boundBy: row).click()
    }

    var pathVariableValue: XCUIElement {
        pane.textFields["pathVariables.value"]
    }

    func pathVariableName(_ name: String) -> XCUIElement {
        pane.staticTexts[name]
    }

    /// Goes to the end first, because a click lands wherever the field's centre falls in the text.
    func append(_ text: String, to field: XCUIElement) {
        field.click()
        app.typeKey(.rightArrow, modifierFlags: .command)
        app.typeText(text)
    }

    var quitAlert: XCUIElement {
        app.dialogs.firstMatch
    }

    /// `typeText` drops a colon from a text field, and a key press delivers it.
    func typeColon() {
        app.typeKey(";", modifierFlags: .shift)
    }

    func waitForValue(_ value: String, of element: XCUIElement) -> Bool {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter.wait(for: [matches], timeout: 10) == .completed
    }

}
