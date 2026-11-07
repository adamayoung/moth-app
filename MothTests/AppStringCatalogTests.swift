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
            ("SIDEBAR_HISTORY_SECTION", "History"),
            ("SIDEBAR_HISTORY_EMPTY", "No History"),
            ("REQUEST_EDITOR_EMPTY_TITLE", "No Request Open"),
            ("REQUEST_EDITOR_EMPTY_DESCRIPTION", "Open a request from the sidebar to edit and send it."),
            ("RESPONSE_EMPTY_TITLE", "No Response"),
            ("RESPONSE_EMPTY_DESCRIPTION", "Send a request to see its response here."),
            ("TAB_STRIP_LABEL", "Request Tabs"),
            ("REQUEST_EDITOR_PANE_LABEL", "Request Editor"),
            ("RESPONSE_PANE_LABEL", "Response"),
            ("MENU_CLOSE", "Close"),
            ("MENU_CLOSE_TAB", "Close Tab"),
            ("MENU_CLOSE_WINDOW", "Close Window"),
            ("TAB_CLOSE_LABEL_%@", "Close %@"),
            ("MENU_NEW_COLLECTION", "New Collection"),
            ("MENU_NEW_FOLDER", "New Folder"),
            ("MENU_NEW_REQUEST", "New Request"),
            ("MENU_NEW_ENVIRONMENT", "New Environment"),
            ("MENU_IMPORT", "Import\u{2026}"),
            ("IMPORT_PROGRESS", "Importing\u{2026}"),
            ("IMPORT_RESULT_DONE", "Done"),
            ("IMPORT_REJECTED", "This file isn\u{2019}t a Postman Collection v2.1 or Environment."),
            ("IMPORT_FAILED", "Moth couldn\u{2019}t import this file. Nothing was added."),
            ("DEFAULT_COLLECTION_NAME", "New Collection"),
            ("DEFAULT_FOLDER_NAME", "New Folder"),
            ("DEFAULT_REQUEST_NAME", "New Request"),
            ("DEFAULT_ENVIRONMENT_NAME", "New Environment"),
            ("SIDEBAR_RENAME", "Rename"),
            ("SIDEBAR_RENAME_FIELD_LABEL", "Name"),
            ("SIDEBAR_DELETE", "Delete\u{2026}"),
            ("SIDEBAR_DELETE_TITLE_%@", "Delete \u{201C}%@\u{201D}?"),
            ("SIDEBAR_DELETE_MESSAGE", "You can\u{2019}t undo this."),
            ("SIDEBAR_DELETE_CONFIRM", "Delete"),
            ("SIDEBAR_DELETE_CANCEL", "Cancel"),
            ("SIDEBAR_GLOBALS", "Globals"),
            ("SIDEBAR_EDIT", "Edit\u{2026}"),
            ("SIDEBAR_VARIABLES", "Variables\u{2026}"),
            ("VARIABLES_COLUMN_ENABLED", "Enabled"),
            ("VARIABLES_COLUMN_VARIABLE", "Variable"),
            ("VARIABLES_COLUMN_INITIAL", "Initial Value"),
            ("VARIABLES_COLUMN_CURRENT", "Current Value"),
            ("VARIABLES_COLUMN_SECRET", "Secret"),
            ("VARIABLES_ADD", "Add Variable"),
            ("VARIABLES_REMOVE", "Remove Variable"),
            ("VARIABLES_DONE", "Done"),
            ("VARIABLES_SECRET_VALUE_LABEL", "Secret Value"),
            ("VARIABLES_SECRET_SHOW", "Show"),
            ("VARIABLES_SECRET_HIDE", "Hide"),
            ("VARIABLES_SECRET_UNAVAILABLE", "Not available on this Mac yet"),
            ("ENVIRONMENT_PICKER_LABEL", "Environment"),
            ("ENVIRONMENT_PICKER_NONE", "No Environment"),
            ("SIDEBAR_ICLOUD_SYNC_OFF", "iCloud Sync Off"),
            ("SIDEBAR_ICLOUD_SYNC_OFF_HELP", "This build has no iCloud container, so your data stays on this Mac."),
            ("STORE_FAILURE_ALERT_TITLE", "Moth can’t open your data."),
            (
                "STORE_FAILURE_ALERT_MESSAGE",
                "Quit, then open Moth again. If this keeps happening, the data may come from a newer version of Moth."
            ),
            (
                "STORE_FAILURE_ALERT_NEWER_SCHEMA_MESSAGE",
                "This data was saved by a newer version of Moth. Update Moth to open it. "
                    + "Your data has not been changed."
            ),
            ("STORE_FAILURE_ALERT_QUIT", "Quit"),
            ("MENU_SAVE", "Save"),
            ("MENU_REVERT_TO_SAVED", "Revert to Saved"),
            ("REQUEST_EDITOR_METHOD_LABEL", "Method"),
            ("REQUEST_EDITOR_URL_LABEL", "URL"),
            ("REQUEST_EDITOR_SECTIONS_LABEL", "Request Sections"),
            ("REQUEST_EDITOR_SECTION_PARAMS", "Params"),
            ("REQUEST_EDITOR_SECTION_HEADERS", "Headers"),
            ("REQUEST_EDITOR_SECTION_BODY", "Body"),
            ("REQUEST_EDITOR_SECTION_AUTH", "Auth"),
            ("REQUEST_EDITOR_PATH_VARIABLES", "Path Variables"),
            ("KEY_VALUE_COLUMN_ENABLED", "Enabled"),
            ("KEY_VALUE_COLUMN_KEY", "Key"),
            ("KEY_VALUE_COLUMN_VALUE", "Value"),
            ("REQUEST_EDITOR_ADD_PARAMETER", "Add Parameter"),
            ("REQUEST_EDITOR_ADD_HEADER", "Add Header"),
            ("REQUEST_EDITOR_REMOVE_PARAMETER", "Remove Parameter"),
            ("REQUEST_EDITOR_REMOVE_HEADER", "Remove Header"),
            ("REQUEST_EDITOR_UNREADABLE_TITLE", "Can\u{2019}t Read This Request"),
            (
                "REQUEST_EDITOR_UNREADABLE_DESCRIPTION",
                "It was saved by a newer version of Moth, or it\u{2019}s damaged."
            ),
            ("TAB_EDITED_LABEL_%@", "%@ has unsaved changes"),
            ("CLOSE_TAB_ALERT_TITLE_%@", "Save changes to \u{201C}%@\u{201D}?"),
            ("CLOSE_TAB_ALERT_SAVE", "Save"),
            ("CLOSE_TAB_ALERT_DONT_SAVE", "Don\u{2019}t Save"),
            ("CLOSE_TAB_ALERT_CANCEL", "Cancel"),
            ("QUIT_ALERT_TITLE", "Quit with unsaved changes?"),
            ("QUIT_ALERT_QUIT", "Quit Anyway"),
            ("BODY_KIND_LABEL", "Body Type"),
            ("BODY_KIND_NONE", "None"),
            ("BODY_KIND_FORM_DATA", "Form Data"),
            ("BODY_KIND_URL_ENCODED", "URL Encoded"),
            ("BODY_KIND_RAW", "Raw"),
            ("BODY_KIND_BINARY", "Binary"),
            ("BODY_KIND_GRAPHQL", "GraphQL"),
            ("RAW_BODY_LABEL", "Body Text"),
            ("RAW_CONTENT_TYPE_LABEL", "Content Type"),
            ("RAW_CONTENT_TYPE_JSON", "JSON"),
            ("RAW_CONTENT_TYPE_TEXT", "Text"),
            ("RAW_CONTENT_TYPE_XML", "XML"),
            ("RAW_CONTENT_TYPE_HTML", "HTML"),
            ("REQUEST_EDITOR_ADD_FIELD", "Add Field"),
            ("REQUEST_EDITOR_REMOVE_FIELD", "Remove Field"),
            ("NOT_SUPPORTED_YET", "Not Supported Yet"),
            ("AUTH_KIND_LABEL", "Auth Type"),
            ("AUTH_KIND_INHERIT", "Inherit"),
            ("AUTH_KIND_NONE", "No Auth"),
            ("AUTH_KIND_BASIC", "Basic Auth"),
            ("AUTH_KIND_BEARER", "Bearer Token"),
            ("AUTH_KIND_API_KEY", "API Key"),
            ("AUTH_KIND_DIGEST", "Digest Auth"),
            ("AUTH_KIND_OAUTH2", "OAuth 2.0"),
            ("AUTH_KIND_AWS_SIGV4", "AWS Signature"),
            ("AUTH_USERNAME", "Username"),
            ("AUTH_PASSWORD", "Password"),
            ("AUTH_TOKEN", "Token"),
            ("AUTH_INHERITED_FROM_%@", "Inherited from \u{201C}%@\u{201D}"),
            ("AUTH_NOTHING_TO_INHERIT", "No auth to inherit"),
            ("SIDEBAR_AUTHORIZATION", "Authorization\u{2026}"),
            ("AUTHORIZATION_CANCEL", "Cancel"),
            ("AUTHORIZATION_SAVE", "Save"),
            ("AUTHORIZATION_SAVE_FAILED", "Moth couldn\u{2019}t save this. Close the sheet and try again."),
            ("QUIT_ALERT_CANCEL", "Cancel"),
            ("REQUEST_EDITOR_SEND", "Send"),
            ("REQUEST_EDITOR_CANCEL_SEND", "Cancel"),
            ("RESPONSE_SENDING", "Sending\u{2026}"),
            ("RESPONSE_CANCELLED", "Request Cancelled"),
            ("RESPONSE_FAILED_CONNECT", "Couldn\u{2019}t Connect"),
            ("RESPONSE_FAILED_TIMEOUT", "Request Timed Out"),
            ("RESPONSE_FAILED_NOT_SENT", "Couldn\u{2019}t Send"),
            ("RESPONSE_SECTIONS_LABEL", "Response Sections"),
            ("RESPONSE_SECTION_BODY", "Body"),
            ("RESPONSE_SECTION_HEADERS", "Headers"),
            ("RESPONSE_SECTION_TIMING", "Timing"),
            ("RESPONSE_BODY_TOO_LARGE", "Response is too large to format."),
            ("RESPONSE_BODY_BINARY", "Binary response"),
            ("RESPONSE_BODY_EMPTY", "Empty Response"),
            ("RESPONSE_TIMING_DNS", "DNS"),
            ("RESPONSE_TIMING_CONNECT", "Connect"),
            ("RESPONSE_TIMING_TLS", "TLS"),
            ("RESPONSE_TIMING_FIRST_BYTE", "First Byte"),
            ("RESPONSE_TIMING_DOWNLOAD", "Download"),
            ("RESPONSE_TIMING_TOTAL", "Total"),
            ("RESPONSE_NOTE_UNDEFINED_VARIABLE_%@", "{{%@}} isn\u{2019}t defined, so it was sent as written."),
            ("RESPONSE_NOTE_MISSING_CREDENTIAL", "Sent without auth, because its credential has no value."),
            ("RESPONSE_NOTE_UNSUPPORTED_AUTH", "Sent without its unsupported auth."),
            ("RESPONSE_NOTE_UNSUPPORTED_BODY", "Sent without its unsupported body.")
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
            ("SIDEBAR_DELETE_CONTAINER_MESSAGE_%lld", 1, "This deletes its 1 request. You can\u{2019}t undo this."),
            ("SIDEBAR_DELETE_CONTAINER_MESSAGE_%lld", 4, "This deletes its 4 requests. You can\u{2019}t undo this."),
            ("SIDEBAR_DELETE_ENVIRONMENT_MESSAGE_%lld", 1, "This deletes its 1 variable. You can\u{2019}t undo this."),
            ("SIDEBAR_DELETE_ENVIRONMENT_MESSAGE_%lld", 6, "This deletes its 6 variables. You can\u{2019}t undo this.")
        ]
    )
    func deleteMessageVariesByCount(key: String, count: Int, expected: String) throws {
        try expectPlural(key: key, count: count, expected: expected)
    }

    @Test(
        "The quit alert's count reads correctly in the singular and the plural",
        arguments: [
            (1, "Your unsaved edits to 1 request will be lost."),
            (2, "Your unsaved edits to 2 requests will be lost.")
        ]
    )
    func quitMessageVariesByCount(count: Int, expected: String) throws {
        try expectPlural(key: "QUIT_ALERT_MESSAGE_%lld", count: count, expected: expected)
    }

    @Test(
        "The note for undefined variables reads correctly in the singular and the plural",
        arguments: [
            (1, "1 variable isn\u{2019}t defined and was sent as written."),
            (3, "3 variables aren\u{2019}t defined and were sent as written.")
        ]
    )
    func undefinedVariablesVariesByCount(count: Int, expected: String) throws {
        try expectPlural(key: "RESPONSE_NOTE_UNDEFINED_VARIABLES_%lld", count: count, expected: expected)
    }

    private func expectPlural(key: String, count: Int, expected: String) throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        let english = try #require(Bundle(url: englishURL))
        let format = english.localizedString(
            forKey: key,
            value: Self.missingValue,
            table: nil
        )

        #expect(String.localizedStringWithFormat(format, count) == expected)
    }

}
