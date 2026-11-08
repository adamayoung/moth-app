//  OAuth2SignInRequestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Testing

struct OAuth2SignInRequestTests {

    private static let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

    private static func request(
        authorizationURL: String = "https://auth.example.com/authorize",
        callbackURL: String = "moth://oauth/callback",
        scope: String = ""
    ) -> OAuth2SignInRequest {
        OAuth2SignInRequest(
            authorizationURL: authorizationURL,
            clientID: "moth app",
            callbackURL: callbackURL,
            scope: scope,
            state: "st4te",
            pkce: pkce
        )
    }

    private static func queryItems(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    @Test("The S256 challenge matches RFC 7636 Appendix B")
    func challengeMatchesTheRFC() {
        #expect(Self.pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("A verifier from 32 random bytes is 43 unreserved characters")
    func randomVerifier() {
        let verifier = PKCE(randomBytes: Data((0 ..< 32).map { UInt8($0 * 8) })).verifier
        let unreserved =
            CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

        #expect(verifier.count == 43)
        #expect(verifier.unicodeScalars.allSatisfy(unreserved.contains))
    }

    @Test("The authorization URL carries the code request, the client, the callback, the state and the challenge")
    func authorizationURL() throws {
        let url = try Self.request(scope: "read write").url()

        #expect(url.host() == "auth.example.com")
        #expect(url.path() == "/authorize")
        #expect(Self.queryItems(of: url) == [
            "response_type": "code",
            "client_id": "moth app",
            "redirect_uri": "moth://oauth/callback",
            "scope": "read write",
            "state": "st4te",
            "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            "code_challenge_method": "S256"
        ])
    }

    @Test("The Auth URL's own query is kept, and an empty Scope is left out")
    func keepsTheAuthURLsQuery() throws {
        let url = try Self.request(authorizationURL: "https://auth.example.com/authorize?audience=api").url()
        let items = Self.queryItems(of: url)

        #expect(items["audience"] == "api")
        #expect(items["scope"] == nil)
        #expect(url.query()?.hasPrefix("audience=api&") == true)
    }

    @Test("An Auth URL that isn't a web address is refused", arguments: ["", "not a url", "moth://authorize"])
    func invalidAuthorizationURL(authorizationURL: String) {
        #expect(throws: OAuth2TokenError.invalidAuthorizationURL) {
            try Self.request(authorizationURL: authorizationURL).url()
        }
    }

    @Test("A custom scheme Callback URL gives its scheme")
    func callbackScheme() throws {
        #expect(try Self.request(callbackURL: "moth://oauth/callback").callbackScheme() == "moth")
    }

    @Test(
        "A Callback URL that isn't a custom scheme is refused",
        arguments: [
            "",
            "https://oauth.pstmn.io/v1/callback",
            "http://localhost:8080/callback",
            "callback",
            "localhost:8080/callback",
            "example.com:443/callback"
        ]
    )
    func callbackNotCustomScheme(callbackURL: String) {
        #expect(throws: OAuth2TokenError.callbackNotCustomScheme) {
            try Self.request(callbackURL: callbackURL).callbackScheme()
        }
    }

    @Test("A callback with the matching state gives its code")
    func readsTheCode() throws {
        let callback = try #require(URL(string: "moth://oauth/callback?code=c0de&state=st4te"))

        #expect(try Self.request().code(from: callback) == "c0de")
    }

    @Test(
        "A callback with another state, or none, is refused",
        arguments: ["moth://oauth/callback?code=c0de&state=other", "moth://oauth/callback?code=c0de"]
    )
    func wrongState(callback: String) throws {
        let callback = try #require(URL(string: callback))

        #expect(throws: OAuth2TokenError.stateMismatch) {
            try Self.request().code(from: callback)
        }
    }

    @Test("A provider's error is reported with its description")
    func providerError() throws {
        let callback = try #require(URL(
            string: "moth://oauth/callback?error=access_denied&error_description=The%20user%20said%20no.&state=st4te"
        ))

        #expect(throws: OAuth2TokenError.signInRefused(error: "access_denied", description: "The user said no.")) {
            try Self.request().code(from: callback)
        }
    }

    @Test("A callback with the right state and no code is refused")
    func noCode() throws {
        let callback = try #require(URL(string: "moth://oauth/callback?state=st4te"))

        #expect(throws: OAuth2TokenError.noAuthorizationCode) {
            try Self.request().code(from: callback)
        }
    }

    @Test("Each sign-in error reads as a sentence")
    func errorDescriptions() {
        #expect(
            OAuth2TokenError.callbackNotCustomScheme.localizedDescription
                == "Moth can only receive a sign-in at a custom URL scheme."
        )
        #expect(
            OAuth2TokenError.signInRefused(error: "access_denied", description: "The user said no.")
                .localizedDescription == "access_denied: The user said no."
        )
        #expect(OAuth2TokenError.signInRefused(error: "access_denied", description: nil).localizedDescription
            == "access_denied")
        #expect(OAuth2TokenError.tokenExpired.localizedDescription == "Token Expired. Get a new access token.")
    }

}
