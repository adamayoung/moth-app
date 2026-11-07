//  GenerateCodeScreen.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import AppKit
import XCTest

@MainActor
struct GenerateCodeScreen {

    /// Mirrors `Clipboard.uiTest`.
    private static let clipboard = NSPasteboard(name: NSPasteboard.Name("MothUITestClipboard"))

    let app: XCUIApplication

    var sheet: XCUIElement {
        app.sheets.firstMatch
    }

    var title: XCUIElement {
        sheet.staticTexts["Generate Code"]
    }

    var code: XCUIElement {
        sheet.textViews["generateCode.text"]
    }

    var copyButton: XCUIElement {
        sheet.buttons["generateCode.copy"]
    }

    var doneButton: XCUIElement {
        sheet.buttons["generateCode.done"]
    }

    func chooseLanguage(_ name: String) {
        sheet.radioButtons[name].click()
    }

    func clearClipboard() {
        Self.clipboard.clearContents()
    }

    func waitForCode(containing text: String) -> Bool {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", text),
            object: code
        )
        return XCTWaiter.wait(for: [matches], timeout: 10) == .completed
    }

    func waitForClipboard(containing text: String) -> Bool {
        let clipboard = Self.clipboard
        let copied = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                clipboard.string(forType: .string)?.contains(text) == true
            },
            object: nil
        )
        return XCTWaiter.wait(for: [copied], timeout: 10) == .completed
    }

    func waitForDismissal() -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        return XCTWaiter.wait(for: [gone], timeout: 10) == .completed
    }

}
