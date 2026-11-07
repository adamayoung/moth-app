//  OAuth2StringCatalogTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import Testing

struct OAuth2StringCatalogTests {

    private static func english() throws -> Bundle {
        let englishURL = try #require(Bundle.main.url(forResource: "en-GB", withExtension: "lproj"))
        return try #require(Bundle(url: englishURL))
    }

    @Test(
        "The OAuth 2.0 pane's copy comes from the catalog with its en-GB value",
        arguments: [
            ("AUTH_OAUTH2_GRANT_TYPE", "Grant Type"),
            ("AUTH_OAUTH2_GRANT_CLIENT_CREDENTIALS", "Client Credentials"),
            ("AUTH_OAUTH2_GRANT_AUTHORIZATION_CODE", "Authorization Code"),
            ("AUTH_OAUTH2_GRANT_AUTHORIZATION_CODE_PKCE", "Authorization Code (With PKCE)"),
            ("AUTH_OAUTH2_GRANT_IMPLICIT", "Implicit"),
            ("AUTH_OAUTH2_GRANT_PASSWORD", "Password Credentials"),
            ("AUTH_OAUTH2_TOKEN_URL", "Token URL"),
            ("AUTH_OAUTH2_CLIENT_ID", "Client ID"),
            ("AUTH_OAUTH2_CLIENT_SECRET", "Client Secret"),
            ("AUTH_OAUTH2_SCOPE", "Scope"),
            ("AUTH_OAUTH2_SCOPE_PROMPT", "Optional"),
            ("AUTH_OAUTH2_ACCESS_TOKEN", "Access Token"),
            ("AUTH_OAUTH2_NO_TOKEN", "No Token"),
            ("AUTH_OAUTH2_TOKEN_EXPIRED", "Token Expired"),
            ("AUTH_OAUTH2_TOKEN_NO_EXPIRY", "Doesn\u{2019}t Expire"),
            ("AUTH_OAUTH2_GET_NEW_TOKEN", "Get New Access Token"),
            ("AUTH_OAUTH2_CLEAR_TOKEN", "Clear Token"),
            ("AUTH_OAUTH2_TOKEN_FAILED", "Couldn\u{2019}t Get Access Token"),
            ("RESPONSE_FAILED_ACCESS_TOKEN", "Couldn\u{2019}t Get Access Token")
        ]
    )
    func catalogHoldsEnglishValue(key: String, expected: String) throws {
        #expect(try Self.english().localizedString(forKey: key, value: "MISSING_FROM_CATALOG", table: nil) == expected)
    }

    @Test("A token's expiry reads as when it expires")
    func expiresReadsAsARelativeTime() throws {
        let format = try Self.english().localizedString(
            forKey: "AUTH_OAUTH2_TOKEN_EXPIRES %@",
            value: "MISSING_FROM_CATALOG",
            table: nil
        )

        #expect(String(format: format, "in 59 minutes") == "Expires in 59 minutes")
    }

    @Test("A failed token request is titled in the response pane")
    @MainActor
    func responseTitle() {
        #expect(SendFailure.Kind.accessTokenFailed.title == "Couldn\u{2019}t Get Access Token")
    }

}
