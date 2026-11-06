//  AuthorizationSheetScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

@MainActor
struct AuthorizationSheetScreen {

    let app: XCUIApplication

    private var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    var fields: AuthFieldsScreen {
        AuthFieldsScreen(root: sheet)
    }

    var saveButton: XCUIElement {
        sheet.buttons["authorization.save"]
    }

    var cancelButton: XCUIElement {
        sheet.buttons["authorization.cancel"]
    }

    func waitToClose() -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: saveButton)
        return XCTWaiter.wait(for: [gone], timeout: 10) == .completed
    }

}
