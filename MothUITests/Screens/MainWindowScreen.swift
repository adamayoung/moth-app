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

    var renameField: XCUIElement {
        sidebar.descendants(matching: .any).matching(identifier: "sidebar.renameField").firstMatch
    }

    var deleteAlert: XCUIElement {
        app.sheets.firstMatch
    }

    func sidebarText(_ text: String) -> XCUIElement {
        sidebar.staticTexts[text]
    }

    func sidebarRow(_ name: String) -> XCUIElement {
        sidebar.outlineRows.containing(NSPredicate(format: "label == %@ OR value == %@", name, name)).firstMatch
    }

    func expand(_ name: String) {
        sidebarRow(name).disclosureTriangles.firstMatch.click()
    }

    func select(_ name: String) {
        sidebarText(name).click()
    }

    func drag(_ name: String, onto target: String) {
        sidebarText(name).click(
            forDuration: 1,
            thenDragTo: sidebarText(target),
            withVelocity: .slow,
            thenHoldForDuration: 1
        )
    }

    func drag(_ name: String, aboveTopOf target: String) {
        let topEdge = sidebarRow(target).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        let start = sidebarText(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.click(forDuration: 1, thenDragTo: topEdge, withVelocity: .slow, thenHoldForDuration: 1)
    }

    func drag(_ name: String, ontoBlankEndOf target: String) {
        let blankEnd = sidebarRow(target).coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
        let start = sidebarText(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.click(forDuration: 1, thenDragTo: blankEnd, withVelocity: .slow, thenHoldForDuration: 1)
    }

    func contextMenuFromBlankEnd(of name: String) -> XCUIElement {
        sidebarRow(name).coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).rightClick()
        return sidebar.menus.firstMatch
    }

    func contextMenu(on name: String) -> XCUIElement {
        sidebarText(name).rightClick()
        return sidebar.menus.firstMatch
    }

    func chooseFromContextMenu(on name: String, _ item: String) {
        contextMenu(on: name).menuItems[item].click()
    }

    func fileMenuItem(_ title: String) -> XCUIElement {
        app.menuBars.menuBarItems["File"].menuItems[title]
    }

    func openFileMenu() {
        app.menuBars.menuBarItems["File"].click()
    }

    func closeMenu() {
        app.typeKey(.escape, modifierFlags: [])
    }

    func chooseFromFileMenu(_ title: String) {
        openFileMenu()
        fileMenuItem(title).click()
    }

    func finishRename(typing name: String) {
        XCTAssertTrue(renameField.waitForExistence(timeout: 10))
        app.typeKey("a", modifierFlags: .command)
        app.typeText(name + "\n")
    }

    func alertText(_ text: String) -> XCUIElement {
        deleteAlert.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    func alertButton(_ title: String) -> XCUIElement {
        deleteAlert.buttons[title]
    }

    func waitForRowToDisappear(_ name: String) -> Bool {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: sidebarText(name)
        )
        return XCTWaiter.wait(for: [gone], timeout: 10) == .completed
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
