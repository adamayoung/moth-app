//  SendRequestTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Values mirror `StubHTTPTransport` and `SeedData` by hand: the stub answers every path but `/wait`, `/refused`,
/// `/timeout` and an unanswered `/digest` with one JSON body, and Health has an empty URL.
final class SendRequestTests: MothTestCase {

    private let statusLine = "200 OK · 142 ms · 22 bytes"

    @MainActor
    private func screens() -> (MainWindowScreen, RequestEditorScreen, ResponseScreen) {
        (MainWindowScreen(app: app), RequestEditorScreen(app: app), ResponseScreen(app: app))
    }

    @MainActor
    private func openListUsers() {
        let (screen, editor, _) = screens()
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Users").waitForExistence(timeout: 10))
        screen.expand("Users")
        XCTAssertTrue(screen.sidebarText("List Users").waitForExistence(timeout: 10))
        screen.select("List Users")
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
    }

    @MainActor
    private func sendListUsers() {
        openListUsers()
        let (_, editor, response) = screens()
        editor.sendButton.click()
        XCTAssertTrue(response.status.waitForExistence(timeout: 10))
    }

    @MainActor
    func testSendShowsTheStatusLine() {
        let (screen, _, response) = screens()
        openListUsers()
        XCTAssertTrue(screen.responseText("No Response").exists)

        screens().1.sendButton.click()

        XCTAssertTrue(response.status.waitForExistence(timeout: 10))
        XCTAssertTrue(response.waitForStatus(statusLine))
        XCTAssertFalse(screen.responseText("No Response").exists)
    }

    @MainActor
    func testSendIsDisabledWithAnEmptyURL() {
        let (screen, editor, _) = screens()
        XCTAssertTrue(screen.sidebarText("Seeded Collection").waitForExistence(timeout: 10))
        screen.expand("Seeded Collection")
        XCTAssertTrue(screen.sidebarText("Health").waitForExistence(timeout: 10))
        screen.select("Health")
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))

        XCTAssertFalse(editor.sendButton.isEnabled)

        editor.urlField.click()
        app.typeText("{{host}}")

        XCTAssertTrue(editor.waitForValue("{{host}}", of: editor.urlField))
        XCTAssertTrue(editor.sendButton.isEnabled)
    }

    @MainActor
    func testCancelShowsRequestCancelled() {
        openListUsers()
        let (_, editor, response) = screens()
        editor.replaceURL(with: "{{host}}/wait")
        XCTAssertTrue(editor.waitForValue("{{host}}/wait", of: editor.urlField))

        editor.sendButton.click()

        XCTAssertTrue(editor.cancelButton.waitForExistence(timeout: 10))
        XCTAssertFalse(editor.sendButton.exists)

        editor.cancelButton.click()

        XCTAssertTrue(response.text("Request Cancelled").waitForExistence(timeout: 10))
        XCTAssertTrue(editor.sendButton.waitForExistence(timeout: 10))
    }

    @MainActor
    func testAnAnsweredDigestChallengeShowsTheFinalResponseAndANote() {
        openListUsers()
        let (_, editor, response) = screens()
        editor.showSection("Auth")
        let fields = editor.authFields
        fields.chooseKind("Digest Auth")
        XCTAssertTrue(fields.usernameField.waitForExistence(timeout: 10))
        fields.usernameField.click()
        app.typeText("ada")
        fields.securePasswordField.click()
        app.typeText("s3cret")
        editor.replaceURL(with: "{{host}}/digest")
        XCTAssertTrue(editor.waitForValue("{{host}}/digest", of: editor.urlField))

        editor.sendButton.click()

        XCTAssertTrue(response.waitForStatus(statusLine))
        XCTAssertTrue(response.text("Sent again to answer a Digest challenge.").waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheBodyTabPrettyPrintsJSON() {
        sendListUsers()
        let (_, _, response) = screens()

        XCTAssertTrue(response.bodyText.waitForExistence(timeout: 10))
        XCTAssertEqual(response.bodyText.value as? String, """
        {
          "id": 1,
          "name": "Moth"
        }
        """)
    }

    @MainActor
    func testTheHeadersTabListsEachHeader() {
        sendListUsers()
        let (_, _, response) = screens()

        response.showSection("Headers")

        XCTAssertTrue(response.text("Content-Type").waitForExistence(timeout: 10))
        XCTAssertTrue(response.text("application/json").exists)
        XCTAssertTrue(response.text("X-Request-Id").exists)
        XCTAssertTrue(response.text("stub").exists)
    }

    @MainActor
    func testTheTimingTabListsOnlyThePhasesThatHappened() {
        sendListUsers()
        let (_, _, response) = screens()

        response.showSection("Timing")

        XCTAssertTrue(response.text("DNS").waitForExistence(timeout: 10))
        XCTAssertTrue(response.text("12 ms").exists)
        XCTAssertTrue(response.text("Connect").exists)
        XCTAssertTrue(response.text("First Byte").exists)
        XCTAssertTrue(response.text("Download").exists)
        XCTAssertTrue(response.text("Total").exists)
        XCTAssertFalse(response.text("TLS").exists)
    }

    @MainActor
    func testAFailureShowsItsTitleAndDescription() {
        openListUsers()
        let (_, editor, response) = screens()
        editor.replaceURL(with: "{{host}}/timeout")
        XCTAssertTrue(editor.waitForValue("{{host}}/timeout", of: editor.urlField))

        editor.sendButton.click()

        XCTAssertTrue(response.text("Request Timed Out").waitForExistence(timeout: 10))
        XCTAssertTrue(response.text("The request timed out.").exists)
    }

    @MainActor
    func testAResponseStaysWithItsTab() {
        sendListUsers()
        let (screen, _, response) = screens()
        screen.select("Create User")
        XCTAssertTrue(screen.requestEditorText("Create User").waitForExistence(timeout: 10))

        XCTAssertTrue(screen.responseText("No Response").waitForExistence(timeout: 10))
        XCTAssertFalse(response.status.exists)

        screen.requestTab("GET List Users").click()

        XCTAssertTrue(response.waitForStatus(statusLine))
    }

    @MainActor
    func testARelaunchReturnsToNoResponse() {
        sendListUsers()
        let (screen, _, _) = screens()

        app.terminate()
        app.launchArguments += ["-UITestRestoresTabs", "1"]
        app.launch()

        XCTAssertTrue(screen.requestTab("GET List Users").waitForExistence(timeout: 10))
        XCTAssertTrue(screen.responseText("No Response").waitForExistence(timeout: 10))
    }

}
