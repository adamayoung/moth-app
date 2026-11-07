//  CookiesSheetTests.swift
//  MothUITests
//
//  Copyright © 2026 Adam Young.

import XCTest

/// Mirrors `SeedData.cookies`: "session" and "csrf" on api.example.com, "theme" on example.org.
final class CookiesSheetTests: MothTestCase {

    @MainActor
    private func openSheet() -> CookiesSheetScreen {
        let window = MainWindowScreen(app: app)
        XCTAssertTrue(window.sidebarText("Seeded Environment").waitForExistence(timeout: 10))
        window.chooseFromFileMenu("Manage Cookies\u{2026}")

        let sheet = CookiesSheetScreen(app: app)
        XCTAssertTrue(sheet.title.waitForExistence(timeout: 10))
        return sheet
    }

    @MainActor
    func testTheSheetGroupsTheCookiesByDomain() {
        let sheet = openSheet()

        for text in ["api.example.com", "example.org", "session", "csrf", "theme", "/v1", "Session"] {
            XCTAssertTrue(sheet.text(text).exists, text)
        }
        XCTAssertLessThan(sheet.text("api.example.com").frame.minY, sheet.text("csrf").frame.minY)
        XCTAssertLessThan(sheet.text("session").frame.minY, sheet.text("example.org").frame.minY)
        XCTAssertLessThan(sheet.text("example.org").frame.minY, sheet.text("theme").frame.minY)
    }

    @MainActor
    func testAValueShowsOnlyOnceItsCookieIsSelected() {
        let sheet = openSheet()

        XCTAssertFalse(sheet.value.exists)
        XCTAssertFalse(sheet.text("seeded-session-value").exists)
        XCTAssertFalse(sheet.deleteButton.isEnabled)

        sheet.text("session").click()

        XCTAssertTrue(sheet.value.waitForExistence(timeout: 10))
        XCTAssertEqual(sheet.value.value as? String, "seeded-session-value")
        XCTAssertFalse(sheet.text("seeded-csrf-value").exists)
    }

    @MainActor
    func testDeleteRemovesTheSelectedCookieAlone() {
        let sheet = openSheet()

        sheet.text("csrf").click()
        sheet.deleteButton.click()

        XCTAssertTrue(sheet.waitForDisappearance(of: sheet.text("csrf")))
        XCTAssertTrue(sheet.text("session").exists)
        XCTAssertTrue(sheet.text("theme").exists)
    }

    @MainActor
    func testDeletingADomainRemovesItsCookies() {
        let sheet = openSheet()

        sheet.deleteDomainButton("api.example.com").click()

        XCTAssertTrue(sheet.waitForDisappearance(of: sheet.text("api.example.com")))
        XCTAssertFalse(sheet.text("session").exists)
        XCTAssertFalse(sheet.text("csrf").exists)
        XCTAssertTrue(sheet.text("theme").exists)
    }

    @MainActor
    func testDeleteAllAsksFirstAndCancelKeepsTheCookies() {
        let sheet = openSheet()

        sheet.deleteAllButton.click()

        XCTAssertTrue(sheet.alertText("Delete all cookies?").waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.alertText("You can\u{2019}t undo this action.").exists)
        sheet.alertButton("Cancel").click()

        XCTAssertTrue(sheet.waitForDisappearance(of: sheet.alertText("Delete all cookies?")))
        XCTAssertTrue(sheet.text("session").exists)
        XCTAssertTrue(sheet.text("theme").exists)
    }

    @MainActor
    func testConfirmingDeleteAllLeavesNoCookies() {
        let sheet = openSheet()

        sheet.deleteAllButton.click()
        XCTAssertTrue(sheet.alertText("Delete all cookies?").waitForExistence(timeout: 10))
        sheet.alertButton("Delete All").click()

        XCTAssertTrue(sheet.text("No Cookies").waitForExistence(timeout: 10))
        XCTAssertFalse(sheet.text("session").exists)
        XCTAssertFalse(sheet.deleteAllButton.isEnabled)
    }

    @MainActor
    func testDoneClosesTheSheet() {
        let sheet = openSheet()

        sheet.doneButton.click()

        XCTAssertTrue(sheet.waitForDisappearance(of: sheet.title))
    }

}
