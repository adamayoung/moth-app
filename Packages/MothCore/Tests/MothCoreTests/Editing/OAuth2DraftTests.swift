//  OAuth2DraftTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct OAuth2DraftTests {

    private nonisolated static let clientSecret = SecretReference(identifier: "client-secret")
    private nonisolated static let accessToken = SecretReference(identifier: "access-token")

    private nonisolated static func oauth2(
        grantType: OAuth2GrantType = .clientCredentials,
        clientSecret: SecretReference? = clientSecret,
        accessToken: SecretReference? = accessToken
    ) -> OAuth2Auth {
        OAuth2Auth(
            grantType: grantType,
            authorizationURL: "https://example.com/authorize",
            accessTokenURL: "https://example.com/token",
            callbackURL: "https://example.com/callback",
            clientID: "moth",
            clientSecret: clientSecret,
            scope: "read",
            username: "ada",
            password: SecretReference(identifier: "password"),
            accessToken: accessToken,
            refreshToken: SecretReference(identifier: "refresh")
        )
    }

    private func oauth2(of draft: AuthDraft) throws -> OAuth2Auth {
        guard case .oauth2(let oauth2) = draft.requestAuth else {
            Issue.record("Expected OAuth 2.0, got \(draft.requestAuth)")
            throw CancellationError()
        }
        return oauth2
    }

    @Test("The picker offers OAuth 2.0")
    func offered() {
        #expect(AuthKind.editable == [.inherit, .none, .basic, .bearer, .apiKey, .digest, .oauth2, .awsSigV4])
        #expect(AuthDraft(.none).kinds == AuthKind.editable)
        #expect(AuthDraft(.oauth2(Self.oauth2(grantType: .implicit))).kinds == AuthKind.editable)
    }

    @Test(
        "A stored auth comes back unchanged, with every field the editor doesn't show, and writes nothing",
        arguments: [
            OAuth2GrantType.clientCredentials,
            .implicit,
            .authorizationCode,
            .authorizationCodeWithPKCE,
            .passwordCredentials
        ]
    )
    func roundTrips(grantType: OAuth2GrantType) {
        let auth = Auth.oauth2(Self.oauth2(grantType: grantType))
        let draft = AuthDraft(auth)

        #expect(draft.kind == .oauth2)
        #expect(draft.requestAuth == auth)
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("The grant types are Client Credentials, plus a stored grant Moth can't run yet")
    func grantTypes() {
        #expect(AuthDraft(.none).oauth2.grantTypes == [.clientCredentials])
        #expect(AuthDraft(.oauth2(Self.oauth2())).oauth2.grantTypes == [.clientCredentials])

        let imported = AuthDraft(.oauth2(Self.oauth2(grantType: .implicit))).oauth2
        #expect(imported.grantTypes == [.clientCredentials, .implicit])
        #expect(imported.grantType == .implicit)
        #expect(!imported.isSupported)
    }

    @Test("Choosing Client Credentials for an imported grant keeps its fields")
    func choosingClientCredentials() throws {
        var draft = AuthDraft(.oauth2(Self.oauth2(grantType: .implicit)))

        draft.oauth2.grantType = .clientCredentials

        #expect(draft.oauth2.isSupported)
        #expect(draft.oauth2.tokenURL == "https://example.com/token")
        #expect(try oauth2(of: draft).grantType == .clientCredentials)
        #expect(try oauth2(of: draft).callbackURL == "https://example.com/callback")
    }

    @Test("A new OAuth 2.0 auth has empty fields, Client Credentials, and a token reference")
    func newAuth() throws {
        var draft = AuthDraft(.none)
        draft.kind = .oauth2
        draft.oauth2.tokenURL = "https://example.com/token"
        draft.oauth2.clientID = "moth"
        draft.oauth2.scope = "read write"

        let auth = try oauth2(of: draft)
        #expect(auth.grantType == .clientCredentials)
        #expect(auth.accessTokenURL == "https://example.com/token")
        #expect(auth.clientID == "moth")
        #expect(auth.scope == "read write")
        #expect(auth.clientSecret == nil)
        #expect(auth.accessToken == draft.oauth2.accessTokenReference)
    }

    @Test("A typed Client Secret takes a new reference and is written on Save")
    func typedSecret() throws {
        var draft = AuthDraft(.oauth2(Self.oauth2()))

        draft.setCredential("typed", for: draft.oauth2.clientSecretReference)

        let auth = try oauth2(of: draft)
        let write = try #require(draft.credentialWrites().first)
        #expect(auth.clientSecret != Self.clientSecret)
        #expect(write.reference == auth.clientSecret)
        #expect(write.value == "typed")
        #expect(draft.typedCredential(for: draft.oauth2.clientSecretReference) == "typed")
        #expect(!draft.hasSameContent(as: AuthDraft(.oauth2(Self.oauth2()))))
    }

    @Test("Clearing the Client Secret leaves no reference, because an empty secret is a client with none")
    func clearedSecret() throws {
        var draft = AuthDraft(.oauth2(Self.oauth2()))

        draft.setCredential("", for: draft.oauth2.clientSecretReference)

        #expect(try oauth2(of: draft).clientSecret == nil)
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("The editor loads the Client Secret, not the token")
    func credentialReferences() {
        let draft = AuthDraft(.oauth2(Self.oauth2()))

        #expect(draft.credentialReferences == [Self.clientSecret])
        #expect(draft.oauth2.accessTokenReference == Self.accessToken)
    }

    @Test("A stored auth with no token reference uses one derived from the auth, and comes back unchanged")
    func derivedTokenReference() {
        let auth = Self.oauth2(accessToken: nil)
        let draft = AuthDraft(.oauth2(auth))

        #expect(draft.oauth2.accessTokenReference == auth.tokenReference)
        #expect(draft.oauth2.accessTokenReference == AuthDraft(.oauth2(auth)).oauth2.accessTokenReference)
        #expect(draft.requestAuth == .oauth2(auth))
        #expect(draft.hasSameContent(as: AuthDraft(.oauth2(auth))))
    }

    @Test("Editing a stored auth with no token reference writes the derived one, so its token stays")
    func editedAuthTakesTheDerivedReference() throws {
        let auth = Self.oauth2(accessToken: nil)
        var draft = AuthDraft(.oauth2(auth))

        draft.oauth2.scope = "write"

        #expect(try oauth2(of: draft).accessToken == auth.tokenReference)
    }

    @Test("Two auths that differ derive different token references, and one with a reference keeps it")
    func tokenReferences() {
        var other = Self.oauth2(accessToken: nil)
        other.clientID = "other"

        #expect(Self.oauth2(accessToken: nil).tokenReference != other.tokenReference)
        #expect(Self.oauth2().tokenReference == Self.accessToken)
    }

    @Test("Following the saved auth takes its fields and drops what was typed")
    func follow() {
        var draft = AuthDraft(.oauth2(Self.oauth2()))
        draft.setCredential("typed", for: draft.oauth2.clientSecretReference)
        var newer = Self.oauth2()
        newer.clientID = "newer"
        newer.scope = "write"
        let saved = AuthDraft(.oauth2(newer))

        draft.follow(saved)

        #expect(draft.requestAuth == .oauth2(newer))
        #expect(draft.hasSameContent(as: saved))
    }

    @Test("A draft following a row with no token reference isn't edited")
    func followWithoutTokenReference() {
        let auth = Auth.oauth2(Self.oauth2(accessToken: nil))
        var draft = AuthDraft(auth)

        draft.follow(AuthDraft(auth))

        #expect(draft.hasSameContent(as: AuthDraft(auth)))
        #expect(draft.requestAuth == auth)
    }

    @Test("Rebasing an edited draft takes the row's references and keeps its fields")
    func rebase() throws {
        let newerSecret = SecretReference(identifier: "newer-secret")
        let newerToken = SecretReference(identifier: "newer-token")
        var draft = AuthDraft(.oauth2(Self.oauth2()))
        draft.oauth2.clientID = "edited"

        draft.rebaseCredentials(onto: AuthDraft(.oauth2(Self.oauth2(
            clientSecret: newerSecret,
            accessToken: newerToken
        ))))

        let auth = try oauth2(of: draft)
        #expect(auth.clientID == "edited")
        #expect(auth.clientSecret == newerSecret)
        #expect(auth.accessToken == newerToken)
    }

}
