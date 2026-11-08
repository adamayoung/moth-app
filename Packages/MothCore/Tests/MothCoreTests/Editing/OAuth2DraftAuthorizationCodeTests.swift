//  OAuth2DraftAuthorizationCodeTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct OAuth2DraftAuthorizationCodeTests {

    private nonisolated static func oauth2(
        grantType: OAuth2GrantType = .authorizationCodeWithPKCE,
        callbackURL: String = "moth://oauth/callback"
    ) -> OAuth2Auth {
        OAuth2Auth(
            grantType: grantType,
            authorizationURL: "https://example.com/authorize",
            accessTokenURL: "https://example.com/token",
            callbackURL: callbackURL,
            clientID: "moth",
            scope: "read",
            accessToken: SecretReference(identifier: "access-token")
        )
    }

    private func oauth2(of draft: AuthDraft) throws -> OAuth2Auth {
        guard case .oauth2(let oauth2) = draft.requestAuth else {
            Issue.record("Expected OAuth 2.0, got \(draft.requestAuth)")
            throw CancellationError()
        }
        return oauth2
    }

    @Test("The Auth URL and Callback URL are edited and saved")
    func editsTheURLs() throws {
        var draft = AuthDraft(.oauth2(Self.oauth2()))
        #expect(draft.oauth2.authorizationURL == "https://example.com/authorize")
        #expect(draft.oauth2.callbackURL == "moth://oauth/callback")

        draft.oauth2.authorizationURL = "https://example.com/oauth/authorize"
        draft.oauth2.callbackURL = "moth://signed-in"

        #expect(try oauth2(of: draft).authorizationURL == "https://example.com/oauth/authorize")
        #expect(try oauth2(of: draft).callbackURL == "moth://signed-in")
        #expect(!draft.hasSameContent(as: AuthDraft(.oauth2(Self.oauth2()))))
    }

    @Test("A new OAuth 2.0 auth's Callback URL is moth://oauth/callback")
    func newAuthHasTheDefaultCallback() throws {
        var draft = AuthDraft(.none)
        draft.kind = .oauth2
        draft.oauth2.grantType = .authorizationCodeWithPKCE

        #expect(draft.oauth2.callbackURL == "moth://oauth/callback")
        #expect(try oauth2(of: draft).callbackURL == "moth://oauth/callback")
    }

    @Test("Choosing Authorization Code fills an empty Callback URL and keeps one already set")
    func choosingTheGrantFillsAnEmptyCallback() {
        var empty = AuthDraft(.oauth2(Self.oauth2(grantType: .clientCredentials, callbackURL: "")))
        var set = AuthDraft(.oauth2(Self.oauth2(grantType: .implicit, callbackURL: "moth://imported")))

        empty.oauth2.grantType = .authorizationCodeWithPKCE
        set.oauth2.grantType = .authorizationCodeWithPKCE

        #expect(empty.oauth2.callbackURL == "moth://oauth/callback")
        #expect(set.oauth2.callbackURL == "moth://imported")
    }

    @Test("Opening a stored auth with an empty Callback URL is no edit")
    func openingIsNoEdit() {
        let auth = Auth.oauth2(Self.oauth2(callbackURL: ""))

        #expect(AuthDraft(auth).requestAuth == auth)
    }

    @Test(
        "A Callback URL that isn't a custom scheme says Moth can't receive a sign-in there",
        arguments: ["https://oauth.pstmn.io/v1/callback", "http://localhost:8080/callback", ""]
    )
    func webCallbackIsAProblem(callbackURL: String) {
        let draft = AuthDraft(.oauth2(Self.oauth2(callbackURL: callbackURL)))

        #expect(draft.oauth2.callbackURLProblem == "Moth can only receive a sign-in at a custom URL scheme.")
    }

    @Test(
        "A custom scheme, a variable, or another grant shows no Callback URL problem",
        arguments: [
            (OAuth2GrantType.authorizationCodeWithPKCE, "moth://oauth/callback"),
            (.authorizationCodeWithPKCE, "{{callbackURL}}"),
            (.clientCredentials, "https://oauth.pstmn.io/v1/callback")
        ]
    )
    func noCallbackProblem(grantType: OAuth2GrantType, callbackURL: String) {
        let draft = AuthDraft(.oauth2(Self.oauth2(grantType: grantType, callbackURL: callbackURL)))

        #expect(draft.oauth2.callbackURLProblem == nil)
    }

    @Test("Following a saved draft takes its Auth URL and Callback URL")
    func followTakesTheURLs() {
        var edited = AuthDraft(.oauth2(Self.oauth2()))
        var saved = AuthDraft(.oauth2(Self.oauth2()))
        saved.oauth2.authorizationURL = "https://example.com/v2/authorize"
        saved.oauth2.callbackURL = "moth://v2"

        edited.follow(saved)

        #expect(edited.oauth2.authorizationURL == "https://example.com/v2/authorize")
        #expect(edited.oauth2.callbackURL == "moth://v2")
    }

}
