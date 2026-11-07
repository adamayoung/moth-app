//  RequestSettingsStringCatalogTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

struct RequestSettingsStringCatalogTests {

    @Test(
        "The request's settings copy comes from the catalog with its en-GB value",
        arguments: [
            ("REQUEST_EDITOR_SECTION_SETTINGS", "Settings"),
            ("REQUEST_SETTINGS_TIMEOUT", "Timeout"),
            ("REQUEST_SETTINGS_SECONDS", "seconds"),
            ("REQUEST_SETTINGS_FOLLOW_REDIRECTS", "Follow Redirects"),
            ("REQUEST_SETTINGS_VERIFY_TLS", "Verify TLS Certificate"),
            ("REQUEST_SETTINGS_TLS_WARNING", "Moth won\u{2019}t check who it\u{2019}s connecting to.")
        ]
    )
    func catalogHoldsEnglishValue(key: String, expected: String) throws {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        let english = try #require(Bundle(url: englishURL))

        #expect(english.localizedString(forKey: key, value: "MISSING_FROM_CATALOG", table: nil) == expected)
    }

    @MainActor
    @Test("The note on an unverified send says the certificate wasn't checked")
    func unverifiedNoteMessage() {
        #expect(ResponseNote.sentWithoutTLSVerification.message == "Sent without verifying the TLS certificate.")
    }

}
