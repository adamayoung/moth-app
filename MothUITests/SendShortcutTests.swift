//  SendShortcutTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `StubHTTPTransport` and `SeedData` by hand: the stub answers every path but `/wait`, `/refused` and
/// `/timeout` with one JSON body, List Users has a URL and a query row, and Health has an empty URL.
final class SendShortcutTests: MothTestCase {

    private let statusLine = "200 OK · 142 ms · 22 bytes"

    @MainActor
    private func screens() -> (MainWindowScreen, RequestEditorScreen, ResponseScreen) {
        (MainWindowScreen(app: app), RequestEditorScreen(app: app), ResponseScreen(app: app))
    }

    @MainActor
    private func open(_ name: String, in folder: String? = nil) {
        let (screen, editor, _) = screens()
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        if let folder {
            XCTAssertTrue(screen.sidebarText(folder).waitForExistence(timeout: 10))
            screen.expand(folder)
        }
        XCTAssertTrue(screen.sidebarText(name).waitForExistence(timeout: 10))
        screen.select(name)
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
    }

    @MainActor
    func testCommandReturnSendsFromTheURLField() {
        open("List Users", in: "Users")
        let (screen, editor, response) = screens()
        editor.urlField.click()

        screen.sendKey()

        XCTAssertTrue(response.waitForStatus(statusLine))
    }

    @MainActor
    func testCommandReturnSendsFromAParameterGrid() {
        open("List Users", in: "Users")
        let (screen, editor, response) = screens()
        XCTAssertTrue(editor.valueField("params", at: 0).waitForExistence(timeout: 10))
        editor.valueField("params", at: 0).click()

        screen.sendKey()

        XCTAssertTrue(response.waitForStatus(statusLine))
    }

    @MainActor
    func testCommandReturnSendsFromTheBodyEditorWhereReturnAddsANewline() {
        open("List Users", in: "Users")
        let (screen, editor, response) = screens()
        editor.showSection("Body")
        editor.chooseBodyKind("Raw")
        XCTAssertTrue(editor.rawBody.waitForExistence(timeout: 10))
        editor.rawBody.click()
        app.typeText("a")
        app.typeKey(.return, modifierFlags: [])
        app.typeText("b")
        XCTAssertTrue(editor.waitForValue("a\nb", of: editor.rawBody))
        XCTAssertFalse(response.status.exists)

        screen.sendKey()

        XCTAssertTrue(response.waitForStatus(statusLine))
        XCTAssertEqual(editor.rawBody.value as? String, "a\nb")
    }

    @MainActor
    func testSendIsDisabledWithNoTabAndWithAnEmptyURL() {
        let (screen, editor, _) = screens()
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.openRequestMenu()
        XCTAssertTrue(screen.requestMenuItem("Send").waitForExistence(timeout: 10))
        XCTAssertFalse(screen.requestMenuItem("Send").isEnabled)
        screen.closeMenu()

        open("Health")
        screen.openRequestMenu()
        XCTAssertFalse(screen.requestMenuItem("Send").isEnabled)
        screen.closeMenu()

        editor.urlField.click()
        app.typeText("{{host}}")
        XCTAssertTrue(editor.waitForValue("{{host}}", of: editor.urlField))
        screen.openRequestMenu()
        XCTAssertTrue(screen.requestMenuItem("Send").isEnabled)
        screen.closeMenu()
    }

    @MainActor
    func testCommandPeriodCancelsAndTheMenuItemReadsCancel() {
        open("List Users", in: "Users")
        let (screen, editor, response) = screens()
        editor.replaceURL(with: "{{host}}/wait")
        XCTAssertTrue(editor.waitForValue("{{host}}/wait", of: editor.urlField))

        screen.sendKey()
        XCTAssertTrue(editor.cancelButton.waitForExistence(timeout: 10))
        screen.openRequestMenu()
        XCTAssertTrue(screen.requestMenuItem("Cancel").waitForExistence(timeout: 10))
        XCTAssertFalse(screen.requestMenuItem("Send").exists)
        screen.closeMenu()

        screen.cancelSendKey()

        XCTAssertTrue(response.text("Request Cancelled").waitForExistence(timeout: 10))
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
    }

}
