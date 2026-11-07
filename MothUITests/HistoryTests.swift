//  HistoryTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `StubHTTPTransport` and `SeedData` by hand: List Users is `https://example.com/users?limit=10`, Update
/// User is `https://example.com/users/:id` with a path row, and the stub answers both with one 22-byte JSON body.
final class HistoryTests: MothTestCase {

    @MainActor
    private func screens() -> (MainWindowScreen, RequestEditorScreen, HistoryScreen) {
        (MainWindowScreen(app: app), RequestEditorScreen(app: app), HistoryScreen(app: app))
    }

    @MainActor
    private func send(_ name: String) {
        let (screen, editor, _) = screens()
        if !screen.sidebarText(name).exists {
            XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
            screen.expand("Seeded Collection")
            XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
            screen.expand("Users")
        }
        XCTAssertTrue(screen.sidebarText(name).waitForExistence(timeout: 10))
        screen.select(name)
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
        editor.sendButton.click()
        XCTAssertTrue(ResponseScreen(app: app).status.waitForExistence(timeout: 10))
    }

    @MainActor
    func testHistoryShowsNoHistoryBeforeAnySend() {
        let (screen, _, history) = screens()

        XCTAssertTrue(screen.sidebarText("No History").waitForExistence(timeout: 10))
        XCTAssertEqual(history.rows.count, 0)
    }

    @MainActor
    func testEachSendAddsAnEntryNewestFirst() {
        let (screen, _, history) = screens()

        send("List Users")
        XCTAssertTrue(history.waitForRowCount(1))
        send("Update User")

        XCTAssertTrue(history.waitForRowCount(2))
        XCTAssertEqual(history.label(of: history.row(0)), "PATCH https://example.com/users/:id")
        XCTAssertEqual(history.label(of: history.row(1)), "GET https://example.com/users?limit=10")
        XCTAssertFalse(screen.sidebarText("No History").exists)
    }

    @MainActor
    func testAnEntryOpensReadOnlyWithItsResponse() {
        let (screen, _, history) = screens()
        send("List Users")
        XCTAssertTrue(history.waitForRowCount(1))

        history.row(0).click()

        XCTAssertTrue(history.entry.waitForExistence(timeout: 10))
        XCTAssertEqual(history.label(of: history.url), "https://example.com/users?limit=10")
        XCTAssertEqual(history.label(of: history.status), "200 OK · 142 ms · 22 bytes")
        XCTAssertTrue(history.entry.staticTexts["Accept"].exists)
        XCTAssertFalse(screen.requestEditorPane.exists)
        XCTAssertEqual(history.entry.textFields.count, 0)
    }

    @MainActor
    func testOpenRequestGoesToTheRequestAndIsDisabledOnceItIsDeleted() {
        let (screen, editor, history) = screens()
        send("List Users")
        XCTAssertTrue(history.waitForRowCount(1))
        history.row(0).click()
        XCTAssertTrue(history.openRequestButton.waitForExistence(timeout: 10))

        history.openRequestButton.click()

        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
        XCTAssertFalse(history.entry.exists)
        XCTAssertTrue(screen.requestTab("List Users").exists)

        screen.chooseFromContextMenu(on: "List Users", "Delete\u{2026}")
        XCTAssertTrue(screen.alertButton("Delete").waitForExistence(timeout: 10))
        screen.alertButton("Delete").click()
        XCTAssertTrue(screen.waitForRowToDisappear("List Users"))
        history.row(0).click()

        XCTAssertTrue(history.openRequestButton.waitForExistence(timeout: 10))
        XCTAssertFalse(history.openRequestButton.isEnabled)
    }

    @MainActor
    func testClearHistoryAsksFirstAndRemovesEveryEntry() {
        let (screen, _, history) = screens()
        send("List Users")
        XCTAssertTrue(history.waitForRowCount(1))

        history.chooseClearHistory(onRow: 0)
        XCTAssertTrue(history.clearAlert.waitForExistence(timeout: 10))
        XCTAssertTrue(history.clearAlert.staticTexts["Clear History?"].exists)
        history.clearAlert.buttons["Cancel"].click()
        XCTAssertEqual(history.rows.count, 1)

        history.chooseClearHistory(onRow: 0)
        XCTAssertTrue(history.clearAlert.waitForExistence(timeout: 10))
        history.clearAlert.buttons["Clear History"].click()

        XCTAssertTrue(history.waitForRowCount(0))
        XCTAssertTrue(screen.sidebarText("No History").waitForExistence(timeout: 10))
    }

}
