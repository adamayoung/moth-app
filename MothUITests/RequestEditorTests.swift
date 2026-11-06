//  RequestEditorTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `SeedData` by hand: List Users has `limit=10`, a disabled `offset=0` and two headers, and Update User
/// has `:id` set to 42.
final class RequestEditorTests: MothTestCase {

    private let listUsersURL = "{{host}}/users?limit=10"

    @MainActor
    private func screenWithListUsersOpen() -> (MainWindowScreen, RequestEditorScreen) {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        screen.select("List Users")
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        return (screen, editor)
    }

    @MainActor
    private func screenWithEditedListUsers() -> (MainWindowScreen, RequestEditorScreen) {
        let (screen, editor) = screenWithListUsersOpen()
        editor.append("/more", to: editor.urlField)
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))
        return (screen, editor)
    }

    @MainActor
    func testFieldsLoadFromASavedRequest() {
        let (_, editor) = screenWithListUsersOpen()

        XCTAssertEqual(editor.methodPicker.value as? String, "GET")
        XCTAssertEqual(editor.urlField.value as? String, listUsersURL)
        XCTAssertEqual(editor.rowCount("params"), 2)
        XCTAssertEqual(editor.keyField("params", at: 0).value as? String, "limit")
        XCTAssertEqual(editor.valueField("params", at: 0).value as? String, "10")
        XCTAssertEqual(editor.enabledCheckbox("params", at: 0).value as? Bool, true)
        XCTAssertEqual(editor.keyField("params", at: 1).value as? String, "offset")
        XCTAssertEqual(editor.enabledCheckbox("params", at: 1).value as? Bool, false)

        editor.showSection("Headers")

        XCTAssertTrue(editor.keyField("headers", at: 0).waitForExistence(timeout: 10))
        XCTAssertEqual(editor.rowCount("headers"), 2)
        XCTAssertEqual(editor.keyField("headers", at: 0).value as? String, "Accept")
        XCTAssertEqual(editor.valueField("headers", at: 0).value as? String, "application/json")
        XCTAssertEqual(editor.enabledCheckbox("headers", at: 1).value as? Bool, false)
    }

    @MainActor
    func testAPathVariableLoadsFromASavedRequest() {
        let (screen, editor) = screenWithListUsersOpen()

        screen.select("Update User")

        XCTAssertTrue(editor.pathVariableValue.waitForExistence(timeout: 10))
        XCTAssertEqual(editor.methodPicker.value as? String, "PATCH")
        XCTAssertTrue(editor.pathVariableName("id").exists)
        XCTAssertEqual(editor.pathVariableValue.value as? String, "42")
    }

    @MainActor
    func testTypingAPathVariableInTheURLAddsItsRow() {
        let (_, editor) = screenWithListUsersOpen()

        editor.urlField.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText("{{host}}/users/")
        editor.typeColon()
        app.typeText("team")

        XCTAssertTrue(editor.pathVariableValue.waitForExistence(timeout: 10))
        XCTAssertTrue(editor.pathVariableName("team").exists)
    }

    @MainActor
    func testAddingAndRemovingAParameterUpdatesTheURL() {
        let (_, editor) = screenWithListUsersOpen()

        editor.addRow("params")
        XCTAssertTrue(editor.keyField("params", at: 2).waitForExistence(timeout: 10))
        editor.append("page", to: editor.keyField("params", at: 2))
        editor.append("2", to: editor.valueField("params", at: 2))

        XCTAssertTrue(editor.waitForValue("\(listUsersURL)&page=2", of: editor.urlField))

        editor.removeRow("params", at: 2)

        XCTAssertTrue(editor.waitForValue(listUsersURL, of: editor.urlField))
        XCTAssertEqual(editor.rowCount("params"), 2)
    }

    @MainActor
    func testEditingTheURLUpdatesParams() {
        let (_, editor) = screenWithListUsersOpen()

        editor.append("&page=2", to: editor.urlField)

        XCTAssertTrue(editor.keyField("params", at: 2).waitForExistence(timeout: 10))
        XCTAssertEqual(editor.keyField("params", at: 2).value as? String, "page")
        XCTAssertEqual(editor.valueField("params", at: 2).value as? String, "2")
    }

    @MainActor
    func testAddingAndRemovingAHeader() {
        let (_, editor) = screenWithListUsersOpen()
        editor.showSection("Headers")
        XCTAssertTrue(editor.keyField("headers", at: 1).waitForExistence(timeout: 10))

        editor.addRow("headers")

        XCTAssertTrue(editor.keyField("headers", at: 2).waitForExistence(timeout: 10))
        XCTAssertEqual(editor.rowCount("headers"), 3)

        editor.removeRow("headers", at: 2)

        XCTAssertFalse(editor.keyField("headers", at: 2).exists)
        XCTAssertEqual(editor.rowCount("headers"), 2)
    }

    @MainActor
    func testEditingShowsTheDotAndSaveClearsIt() {
        let (screen, editor) = screenWithEditedListUsers()

        screen.saveKey()

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))
        XCTAssertTrue(editor.waitForValue("{{host}}/users?limit=10%2Fmore", of: editor.urlField))
    }

    @MainActor
    func testFileMenuSavesTheDraft() {
        let (screen, _) = screenWithEditedListUsers()

        screen.chooseFromFileMenu("Save")

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))
    }

    @MainActor
    func testSaveAndRevertAreDisabledWithNoEdits() {
        let (screen, editor) = screenWithListUsersOpen()

        screen.openFileMenu()
        XCTAssertFalse(screen.fileMenuItem("Save").isEnabled)
        XCTAssertFalse(screen.fileMenuItem("Revert to Saved").isEnabled)
        screen.closeMenu()

        editor.append("/more", to: editor.urlField)
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))

        screen.openFileMenu()
        XCTAssertTrue(screen.fileMenuItem("Save").isEnabled)
        XCTAssertTrue(screen.fileMenuItem("Revert to Saved").isEnabled)
        screen.fileMenuItem("Revert to Saved").click()

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))

        screen.openFileMenu()
        XCTAssertFalse(screen.fileMenuItem("Save").isEnabled)
        XCTAssertFalse(screen.fileMenuItem("Revert to Saved").isEnabled)
        screen.closeMenu()
    }

    @MainActor
    func testRevertToSavedRestoresTheFields() {
        let (screen, editor) = screenWithEditedListUsers()

        screen.chooseFromFileMenu("Revert to Saved")

        XCTAssertTrue(editor.waitForValue(listUsersURL, of: editor.urlField))
    }

    @MainActor
    func testClosingAnEditedTabAsksAndSaveClosesIt() {
        let (screen, editor) = screenWithEditedListUsers()

        screen.closeTabKey()

        XCTAssertTrue(screen.alertText("Save changes to \u{201C}List Users\u{201D}?").waitForExistence(timeout: 10))
        screen.alertButton("Save").click()

        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))
        screen.select("List Users")
        XCTAssertTrue(editor.waitForValue("{{host}}/users?limit=10%2Fmore", of: editor.urlField))
        XCTAssertFalse(screen.editedDot(on: "List Users").exists)
    }

    @MainActor
    func testDontSaveClosesTheTabAndDiscardsTheDraft() {
        let (screen, editor) = screenWithEditedListUsers()

        screen.requestTabCloseButton("Close List Users").click()
        XCTAssertTrue(screen.alertButton("Don\u{2019}t Save").waitForExistence(timeout: 10))
        screen.alertButton("Don\u{2019}t Save").click()

        XCTAssertTrue(screen.waitForTabToClose("GET List Users"))
        screen.select("List Users")
        XCTAssertTrue(editor.waitForValue(listUsersURL, of: editor.urlField))
        XCTAssertFalse(screen.editedDot(on: "List Users").exists)
    }

    @MainActor
    func testCancelKeepsTheEditedTabOpen() {
        let (screen, editor) = screenWithEditedListUsers()

        screen.closeTabKey()
        XCTAssertTrue(screen.alertButton("Cancel").waitForExistence(timeout: 10))
        screen.alertButton("Cancel").click()

        XCTAssertTrue(screen.requestTab("GET List Users").exists)
        XCTAssertTrue(screen.editedDot(on: "List Users").exists)
        XCTAssertEqual(editor.urlField.value as? String, "{{host}}/users?limit=10/more")
    }

    @MainActor
    func testADraftSurvivesATabSwitch() {
        let (screen, editor) = screenWithEditedListUsers()

        screen.select("Create User")
        XCTAssertTrue(screen.requestTab("POST Create User").waitForExistence(timeout: 10))
        screen.requestTab("GET List Users").click()

        XCTAssertTrue(editor.waitForValue("{{host}}/users?limit=10/more", of: editor.urlField))
        XCTAssertTrue(screen.editedDot(on: "List Users").exists)
    }

    @MainActor
    func testQuittingWithEditsAsksAndReturnKeepsMothOpen() {
        let (screen, editor) = screenWithEditedListUsers()
        screen.select("Create User")
        XCTAssertTrue(screen.requestTab("POST Create User").waitForExistence(timeout: 10))
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.append("/more", to: editor.urlField)
        XCTAssertTrue(screen.editedDot(on: "Create User").waitForExistence(timeout: 10))

        app.typeKey("q", modifierFlags: .command)

        let alert = editor.quitAlert
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["Quit with unsaved changes?"].exists)
        XCTAssertTrue(alert.staticTexts["Your unsaved edits to 2 requests will be lost."].exists)
        XCTAssertTrue(alert.buttons["Quit Anyway"].exists)
        XCTAssertTrue(alert.buttons["Cancel"].exists)
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(screen.editedDot(on: "Create User").waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }

}
