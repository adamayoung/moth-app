//  ResponseScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct ResponseScreen {

    let app: XCUIApplication

    private var pane: XCUIElement {
        app.windows.firstMatch.descendants(matching: .any).matching(identifier: "responsePane").firstMatch
    }

    var status: XCUIElement {
        pane.staticTexts["response.status"]
    }

    var bodyText: XCUIElement {
        pane.textViews["response.body"]
    }

    func text(_ text: String) -> XCUIElement {
        pane.staticTexts[text]
    }

    func showSection(_ title: String) {
        pane.radioButtons[title].click()
    }

    func waitForStatus(_ value: String) -> Bool {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", value, value),
            object: status
        )
        return XCTWaiter.wait(for: [matches], timeout: 10) == .completed
    }

}
