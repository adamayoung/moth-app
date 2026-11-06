//  AppStringCatalogTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import Testing

struct AppStringCatalogTests {

    private static let missingValue = "MISSING_FROM_CATALOG"

    @Test(
        "The window's copy comes from the catalog with its en-GB value",
        arguments: [
            ("SIDEBAR_COLLECTIONS_SECTION", "Collections"),
            ("SIDEBAR_COLLECTIONS_EMPTY", "No Collections"),
            ("SIDEBAR_ENVIRONMENTS_SECTION", "Environments"),
            ("SIDEBAR_ENVIRONMENTS_EMPTY", "No Environments"),
            ("SIDEBAR_HISTORY_SECTION", "History"),
            ("SIDEBAR_HISTORY_EMPTY", "No History"),
            ("REQUEST_EDITOR_EMPTY_TITLE", "No Request Open"),
            ("REQUEST_EDITOR_EMPTY_DESCRIPTION", "Open a request from the sidebar to edit and send it."),
            ("RESPONSE_EMPTY_TITLE", "No Response"),
            ("RESPONSE_EMPTY_DESCRIPTION", "Send a request to see its response here."),
            ("TAB_STRIP_LABEL", "Request Tabs"),
            ("REQUEST_EDITOR_PANE_LABEL", "Request Editor"),
            ("RESPONSE_PANE_LABEL", "Response"),
            ("SIDEBAR_ICLOUD_SYNC_OFF", "iCloud Sync Off"),
            ("SIDEBAR_ICLOUD_SYNC_OFF_HELP", "This build has no iCloud container, so your data stays on this Mac."),
            ("STORE_FAILURE_ALERT_TITLE", "Moth can’t open your data."),
            (
                "STORE_FAILURE_ALERT_MESSAGE",
                "Quit, then open Moth again. If this keeps happening, the data may come from a newer version of Moth."
            ),
            ("STORE_FAILURE_ALERT_QUIT", "Quit")
        ]
    )
    func catalogHoldsEnglishValue(key: String, expected: String) throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        let english = try #require(Bundle(url: englishURL))

        #expect(english.localizedString(forKey: key, value: Self.missingValue, table: nil) == expected)
    }

}
