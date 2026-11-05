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
            ("MENU_NEW_COLLECTION", "New Collection"),
            ("MENU_NEW_FOLDER", "New Folder"),
            ("MENU_NEW_REQUEST", "New Request"),
            ("DEFAULT_COLLECTION_NAME", "New Collection"),
            ("DEFAULT_FOLDER_NAME", "New Folder"),
            ("DEFAULT_REQUEST_NAME", "New Request"),
            ("SIDEBAR_RENAME", "Rename"),
            ("SIDEBAR_RENAME_FIELD_LABEL", "Name"),
            ("SIDEBAR_DELETE", "Delete\u{2026}"),
            ("SIDEBAR_DELETE_TITLE_%@", "Delete \u{201C}%@\u{201D}?"),
            ("SIDEBAR_DELETE_MESSAGE", "You can\u{2019}t undo this."),
            ("SIDEBAR_DELETE_CONFIRM", "Delete"),
            ("SIDEBAR_DELETE_CANCEL", "Cancel")
        ]
    )
    func catalogHoldsEnglishValue(key: String, expected: String) throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        let english = try #require(Bundle(url: englishURL))

        #expect(english.localizedString(forKey: key, value: Self.missingValue, table: nil) == expected)
    }

    @Test(
        "The delete alert's count reads correctly in the singular and the plural",
        arguments: [
            (1, "This deletes its 1 request. You can\u{2019}t undo this."),
            (4, "This deletes its 4 requests. You can\u{2019}t undo this.")
        ]
    )
    func deleteMessageVariesByCount(count: Int, expected: String) throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        let english = try #require(Bundle(url: englishURL))
        let format = english.localizedString(
            forKey: "SIDEBAR_DELETE_CONTAINER_MESSAGE_%lld",
            value: Self.missingValue,
            table: nil
        )

        #expect(String.localizedStringWithFormat(format, count) == expected)
    }

}
