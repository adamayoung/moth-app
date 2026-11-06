//  QuitConfirmationAlertTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import Testing

@MainActor
struct QuitConfirmationAlertTests {

    @Test("With no edits Moth quits without asking")
    func noEditsAsksNothing() {
        #expect(QuitConfirmationAlert(editedRequestCount: 0) == nil)
    }

    @Test(
        "The alert states the count and its exact text",
        arguments: [
            (1, "Your unsaved edits to 1 request will be lost."),
            (2, "Your unsaved edits to 2 requests will be lost.")
        ]
    )
    func alertText(count: Int, message: String) throws {
        let alert = try #require(QuitConfirmationAlert(editedRequestCount: count))

        #expect(alert.title == "Quit with unsaved changes?")
        #expect(alert.message == message)
        #expect(alert.quitButton == "Quit Anyway")
        #expect(alert.cancelButton == "Cancel")
    }

}
