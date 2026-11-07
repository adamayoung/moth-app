//  RequestSettingsTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// List Users is seeded with the default settings: 60 seconds, redirects followed, TLS verified.
final class RequestSettingsTests: MothTestCase {

    @MainActor
    private func openListUsersSettings() -> (MainWindowScreen, RequestEditorScreen) {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        screen.select("List Users")
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.showSection("Settings")
        XCTAssertTrue(editor.timeoutField.waitForExistence(timeout: 10))
        return (screen, editor)
    }

    @MainActor
    func testSettingsShowTheThreeControlsWithTheirDefaults() {
        let (_, editor) = openListUsersSettings()

        XCTAssertTrue(editor.waitForValue("60", of: editor.timeoutField))
        XCTAssertTrue(editor.isOn(editor.followRedirectsToggle))
        XCTAssertTrue(editor.isOn(editor.verifyTLSToggle))
        XCTAssertFalse(editor.tlsWarning.exists)
    }

    @MainActor
    func testTimeoutRevertsOnAnInvalidValue() {
        let (screen, editor) = openListUsersSettings()

        editor.replaceTimeout(with: "0")
        editor.urlField.click()

        XCTAssertTrue(editor.waitForValue("60", of: editor.timeoutField))
        XCTAssertFalse(screen.editedDot(on: "List Users").exists)
    }

    @MainActor
    func testTurningVerificationOffShowsTheWarning() {
        let (_, editor) = openListUsersSettings()

        editor.verifyTLSToggle.click()

        XCTAssertTrue(editor.tlsWarning.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Moth won\u{2019}t check who it\u{2019}s connecting to."].exists)
    }

    @MainActor
    func testSaveKeepsTheSettings() {
        let (screen, editor) = openListUsersSettings()

        editor.replaceTimeout(with: "15")
        editor.followRedirectsToggle.click()
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))
        screen.saveKey()

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))
        XCTAssertTrue(editor.waitForValue("15", of: editor.timeoutField))
        XCTAssertFalse(editor.isOn(editor.followRedirectsToggle))
    }

    @MainActor
    func testRevertToSavedRestoresTheSettings() {
        let (screen, editor) = openListUsersSettings()
        editor.replaceTimeout(with: "15")
        editor.verifyTLSToggle.click()
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))

        screen.chooseFromFileMenu("Revert to Saved")

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))
        XCTAssertTrue(editor.waitForValue("60", of: editor.timeoutField))
        XCTAssertTrue(editor.isOn(editor.verifyTLSToggle))
        XCTAssertFalse(editor.tlsWarning.exists)
    }

    @MainActor
    func testAnUnsavedSendWithoutVerificationShowsTheNote() {
        let (screen, editor) = openListUsersSettings()
        let response = ResponseScreen(app: app)
        editor.verifyTLSToggle.click()
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))

        editor.sendButton.click()

        XCTAssertTrue(response.text("Sent without verifying the TLS certificate.").waitForExistence(timeout: 10))
    }

}
