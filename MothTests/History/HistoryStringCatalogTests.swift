//  HistoryStringCatalogTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import Testing

struct HistoryStringCatalogTests {

    @Test(
        "History's copy comes from the catalog with its en-GB value",
        arguments: [
            ("HISTORY_CLEAR", "Clear History\u{2026}"),
            ("HISTORY_CLEAR_ALERT_TITLE", "Clear History?"),
            ("HISTORY_CLEAR_ALERT_MESSAGE", "This removes every request in History on this Mac."),
            ("HISTORY_CLEAR_CONFIRM", "Clear History"),
            ("HISTORY_CLEAR_CANCEL", "Cancel"),
            ("HISTORY_SEND_AGAIN", "Send Again"),
            ("HISTORY_OPEN_REQUEST", "Open Request"),
            ("HISTORY_SECRET_UNAVAILABLE", "Secret unavailable"),
            ("HISTORY_BODY_NOT_KEPT", "Body not kept"),
            ("HISTORY_ROW_FAILED", "Failed"),
            ("HISTORY_ENTRY_GONE", "This entry is no longer in History."),
            ("HISTORY_ENTRY_LABEL", "History Entry"),
            ("HISTORY_REQUEST_HEADERS", "Headers"),
            ("HISTORY_REQUEST_BODY", "Body"),
            ("HISTORY_REQUEST_AUTH", "Auth")
        ]
    )
    func catalogHoldsEnglishValue(key: String, expected: String) throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        let english = try #require(Bundle(url: englishURL))

        #expect(english.localizedString(forKey: key, value: "MISSING_FROM_CATALOG", table: nil) == expected)
    }

}
