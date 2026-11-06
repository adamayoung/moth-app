//  RequestBodyTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `SeedData` by hand: List Users has no body, Create User has form-data with a text row and a file row,
/// Update User has a GraphQL body and Health has a binary body.
final class RequestBodyTests: MothTestCase {

    @MainActor
    private func openBody(of name: String) -> (MainWindowScreen, RequestEditorScreen) {
        let screen = MainWindowScreen(app: app)
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText(name).waitForExistence(timeout: 10))
        screen.select(name)
        let editor = RequestEditorScreen(app: app)
        XCTAssertTrue(editor.urlField.waitForExistence(timeout: 10))
        editor.showSection("Body")
        XCTAssertTrue(editor.bodyKindPicker.waitForExistence(timeout: 10))
        return (screen, editor)
    }

    @MainActor
    func testBodyOffersNoneFormDataURLEncodedAndRaw() {
        let (_, editor) = openBody(of: "List Users")

        XCTAssertEqual(editor.bodyKindPicker.value as? String, "None")

        editor.bodyKindPicker.click()
        for title in ["None", "Form Data", "URL Encoded", "Raw"] {
            XCTAssertTrue(editor.bodyKindPicker.menuItems[title].waitForExistence(timeout: 10), title)
        }
        XCTAssertEqual(editor.bodyKindPicker.menuItems.count, 4)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testEachBodyOptionShowsItsFields() {
        let (_, editor) = openBody(of: "List Users")
        XCTAssertFalse(editor.rawBody.exists)
        XCTAssertFalse(editor.addRowButton("urlEncoded").exists)
        XCTAssertFalse(editor.addRowButton("formData").exists)

        editor.chooseBodyKind("Raw")
        XCTAssertTrue(editor.rawBody.waitForExistence(timeout: 10))
        XCTAssertTrue(editor.rawTypePicker.exists)

        editor.chooseBodyKind("URL Encoded")
        XCTAssertTrue(editor.addRowButton("urlEncoded").waitForExistence(timeout: 10))
        XCTAssertFalse(editor.rawBody.exists)
        XCTAssertFalse(editor.rawTypePicker.exists)

        editor.chooseBodyKind("Form Data")
        XCTAssertTrue(editor.addRowButton("formData").waitForExistence(timeout: 10))
        XCTAssertFalse(editor.addRowButton("urlEncoded").exists)

        editor.chooseBodyKind("None")
        XCTAssertTrue(editor.waitForValue("None", of: editor.bodyKindPicker))
        XCTAssertFalse(editor.addRowButton("formData").exists)
        XCTAssertFalse(editor.rawBody.exists)
    }

    @MainActor
    func testChoosingARawContentTypeStaysAfterSave() {
        let (screen, editor) = openBody(of: "List Users")
        editor.chooseBodyKind("Raw")
        XCTAssertTrue(editor.rawTypePicker.waitForExistence(timeout: 10))
        XCTAssertEqual(editor.rawTypePicker.value as? String, "JSON")

        editor.rawTypePicker.click()
        for title in ["JSON", "Text", "XML", "HTML"] {
            XCTAssertTrue(editor.rawTypePicker.menuItems[title].waitForExistence(timeout: 10), title)
        }
        editor.rawTypePicker.menuItems["XML"].click()

        XCTAssertTrue(editor.waitForValue("XML", of: editor.rawTypePicker))
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))

        screen.saveKey()
        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))

        screen.select("Create User")
        XCTAssertTrue(screen.requestTab("POST Create User").waitForExistence(timeout: 10))
        screen.requestTab("GET List Users").click()
        XCTAssertTrue(editor.waitForValue("XML", of: editor.rawTypePicker))
    }

    @MainActor
    func testAddingAndRemovingAURLEncodedRow() {
        let (_, editor) = openBody(of: "List Users")
        editor.chooseBodyKind("URL Encoded")
        XCTAssertTrue(editor.addRowButton("urlEncoded").waitForExistence(timeout: 10))
        XCTAssertEqual(editor.rowCount("urlEncoded"), 0)

        editor.addRow("urlEncoded")
        XCTAssertTrue(editor.keyField("urlEncoded", at: 0).waitForExistence(timeout: 10))
        editor.append("name", to: editor.keyField("urlEncoded", at: 0))
        editor.append("Ada", to: editor.valueField("urlEncoded", at: 0))

        XCTAssertEqual(editor.keyField("urlEncoded", at: 0).value as? String, "name")
        XCTAssertEqual(editor.valueField("urlEncoded", at: 0).value as? String, "Ada")
        XCTAssertEqual(editor.enabledCheckbox("urlEncoded", at: 0).value as? Bool, true)

        editor.removeRow("urlEncoded", at: 0)

        XCTAssertFalse(editor.keyField("urlEncoded", at: 0).exists)
        XCTAssertEqual(editor.rowCount("urlEncoded"), 0)
    }

    @MainActor
    func testAddingAndRemovingAFormDataRow() {
        let (_, editor) = openBody(of: "List Users")
        editor.chooseBodyKind("Form Data")
        XCTAssertTrue(editor.addRowButton("formData").waitForExistence(timeout: 10))

        editor.addRow("formData")
        XCTAssertTrue(editor.keyField("formData", at: 0).waitForExistence(timeout: 10))
        editor.append("name", to: editor.keyField("formData", at: 0))
        editor.append("Ada", to: editor.valueField("formData", at: 0))

        XCTAssertEqual(editor.valueField("formData", at: 0).value as? String, "Ada")
        XCTAssertEqual(editor.enabledCheckbox("formData", at: 0).value as? Bool, true)

        editor.removeRow("formData", at: 0)

        XCTAssertFalse(editor.keyField("formData", at: 0).exists)
    }

    @MainActor
    func testAFormDataFileRowShowsNotSupportedAndSaveKeepsIt() {
        let (screen, editor) = openBody(of: "Create User")

        XCTAssertTrue(editor.keyField("formData", at: 1).waitForExistence(timeout: 10))
        XCTAssertEqual(editor.rowCount("formData"), 2)
        XCTAssertEqual(editor.keyField("formData", at: 1).value as? String, "photo")
        XCTAssertEqual(editor.formDataNotSupported.value as? String, "Not Supported Yet")
        XCTAssertFalse(editor.keyField("formData", at: 1).isEnabled)
        XCTAssertEqual(editor.removeButtonCount("formData"), 1)

        editor.append("!", to: editor.valueField("formData", at: 0))
        XCTAssertTrue(screen.editedDot(on: "Create User").waitForExistence(timeout: 10))
        screen.saveKey()
        XCTAssertTrue(screen.waitForEditedDotToClear(on: "Create User"))

        XCTAssertEqual(editor.valueField("formData", at: 0).value as? String, "Ada!")
        XCTAssertEqual(editor.formDataNotSupported.value as? String, "Not Supported Yet")
    }

    @MainActor
    func testABinaryBodyShowsNotSupported() {
        let (screen, editor) = openBody(of: "Health")

        XCTAssertEqual(editor.bodyKindPicker.value as? String, "Binary")
        XCTAssertTrue(editor.bodyNotSupported.waitForExistence(timeout: 10))
        XCTAssertEqual(editor.bodyNotSupported.value as? String, "Not Supported Yet")
        XCTAssertFalse(screen.editedDot(on: "Health").exists)
    }

    @MainActor
    func testAGraphQLBodyShowsNotSupported() {
        let (screen, editor) = openBody(of: "Update User")

        XCTAssertEqual(editor.bodyKindPicker.value as? String, "GraphQL")
        XCTAssertTrue(editor.bodyNotSupported.waitForExistence(timeout: 10))
        XCTAssertEqual(editor.bodyNotSupported.value as? String, "Not Supported Yet")
        XCTAssertFalse(screen.editedDot(on: "Update User").exists)
    }

    @MainActor
    func testABodyEditShowsTheDotAndSaveKeepsIt() {
        let (screen, editor) = openBody(of: "List Users")
        editor.chooseBodyKind("Raw")
        XCTAssertTrue(editor.rawBody.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))

        editor.rawBody.click()
        app.typeText("hello")
        XCTAssertTrue(editor.waitForValue("hello", of: editor.rawBody))

        screen.saveKey()

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))
        XCTAssertTrue(editor.waitForValue("hello", of: editor.rawBody))
    }

    @MainActor
    func testUndoingABodyKindChangeClearsTheDot() {
        let (screen, editor) = openBody(of: "List Users")
        editor.chooseBodyKind("Raw")
        XCTAssertTrue(screen.editedDot(on: "List Users").waitForExistence(timeout: 10))

        editor.chooseBodyKind("None")

        XCTAssertTrue(screen.waitForEditedDotToClear(on: "List Users"))
    }

}
