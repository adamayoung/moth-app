//  HistoryScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct HistoryScreen {

    let app: XCUIApplication

    private var window: XCUIElement {
        app.windows.firstMatch
    }

    private var sidebar: XCUIElement {
        window.descendants(matching: .any).matching(identifier: "sidebar").firstMatch
    }

    var entry: XCUIElement {
        window.descendants(matching: .any).matching(identifier: "history.entry").firstMatch
    }

    var rows: XCUIElementQuery {
        sidebar.buttons.matching(identifier: "history.row")
    }

    var url: XCUIElement {
        entry.staticTexts["history.url"]
    }

    var status: XCUIElement {
        entry.staticTexts["response.status"]
    }

    var openRequestButton: XCUIElement {
        entry.buttons["history.openRequest"]
    }

    var sendAgainButton: XCUIElement {
        entry.buttons["history.sendAgain"]
    }

    var clearAlert: XCUIElement {
        app.sheets.firstMatch
    }

    func row(_ index: Int) -> XCUIElement {
        rows.element(boundBy: index)
    }

    func waitForRowCount(_ count: Int) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: rows)
        return XCTWaiter.wait(for: [matches], timeout: 10) == .completed
    }

    func chooseClearHistory(onRow index: Int) {
        row(index).rightClick()
        sidebar.menus.firstMatch.menuItems["Clear History\u{2026}"].click()
    }

    func label(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

}
