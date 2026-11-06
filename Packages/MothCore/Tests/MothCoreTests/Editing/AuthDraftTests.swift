//  AuthDraftTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct AuthDraftTests {

    private nonisolated static let password = SecretReference(identifier: "password")
    private nonisolated static let token = SecretReference(identifier: "token")

    private nonisolated static let unsupported: [Auth] = [
        .apiKey(APIKeyAuth(name: "X-Key", value: SecretReference(identifier: "key"), location: .header)),
        .digest(DigestAuth(username: "ada", password: SecretReference(identifier: "digest"))),
        .oauth2(OAuth2Auth(
            grantType: .clientCredentials,
            authorizationURL: "",
            accessTokenURL: "https://example.com/token",
            callbackURL: "",
            clientID: "client",
            clientSecret: SecretReference(identifier: "client-secret"),
            scope: ""
        )),
        .awsSigV4(AWSSigV4Auth(
            accessKeyID: SecretReference(identifier: "access"),
            secretAccessKey: SecretReference(identifier: "secret"),
            region: "eu-west-2",
            service: "s3"
        ))
    ]

    private let basic = Auth.basic(BasicAuth(username: "ada", password: Self.password))
    private let bearer = Auth.bearer(BearerAuth(token: Self.token))

    @Test("Each auth comes back unchanged from a draft nobody edited", arguments: [
        Auth.inherit,
        .none,
        .basic(BasicAuth(username: "ada", password: password)),
        .bearer(BearerAuth(token: token))
    ] + unsupported)
    func roundTrips(auth: Auth) {
        #expect(AuthDraft(auth).requestAuth == auth)
    }

    @Test("The kinds are the four editable ones, plus a stored kind the editor can't change")
    func kinds() throws {
        #expect(AuthDraft(.none).kinds == [.inherit, .none, .basic, .bearer])
        let apiKey = try #require(Self.unsupported.first)
        #expect(AuthDraft(apiKey).kinds == [.inherit, .none, .basic, .bearer, .apiKey])
    }

    @Test("Choosing another kind and back keeps an auth the editor can't change", arguments: unsupported)
    func unsupportedAuthSurvivesASwitch(auth: Auth) {
        var draft = AuthDraft(auth)
        let kept = draft.kind

        draft.kind = .bearer
        draft.kind = kept

        #expect(draft.requestAuth == auth)
    }

    @Test("Choosing another kind and back restores the stored auth, with nothing to save")
    func switchingBackIsNoChange() {
        let saved = AuthDraft(basic)
        var draft = saved

        draft.kind = .bearer
        #expect(!draft.hasSameContent(as: saved))

        draft.kind = .basic
        #expect(draft.requestAuth == basic)
        #expect(draft.hasSameContent(as: saved))
    }

    @Test("A new credential keeps its reference, so a Save tried again writes the same item")
    func newReferenceIsStable() {
        var draft = AuthDraft(.none)
        draft.kind = .bearer
        let first = draft.requestAuth

        draft.kind = .none
        draft.kind = .bearer

        #expect(draft.requestAuth == first)
    }

    @Test("A username is part of the content")
    func usernameIsContent() {
        var draft = AuthDraft(basic)

        draft.username = "grace"

        #expect(draft.requestAuth == .basic(BasicAuth(username: "grace", password: Self.password)))
        #expect(!draft.hasSameContent(as: AuthDraft(basic)))
    }

    @Test("A typed credential never reaches the auth that goes to a row")
    func typedCredentialStaysOutOfRequestAuth() throws {
        var draft = AuthDraft(bearer)

        draft.setCredential("s3cret", for: Self.token)

        #expect(draft.requestAuth == bearer)
        let encoded = try JSONEncoder().encode(draft.requestAuth)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("s3cret"))
    }

    @Test("A typed credential counts as a change, until it is discarded")
    func typedCredentialIsAChange() {
        var draft = AuthDraft(bearer)

        draft.setCredential("s3cret", for: Self.token)
        #expect(draft.typedCredential(for: Self.token) == "s3cret")
        #expect(!draft.hasSameContent(as: AuthDraft(bearer)))

        draft.discardCredentials { reference, text in reference == Self.token && text == "s3cret" }
        #expect(draft.typedCredential(for: Self.token) == nil)
        #expect(draft.hasSameContent(as: AuthDraft(bearer)))
    }

    @Test("Typing for a kind that isn't chosen is no change")
    func hiddenKindsTypingIsNoChange() {
        var draft = AuthDraft(bearer)

        draft.kind = .basic
        draft.setCredential("typed", for: draft.passwordReference)
        draft.kind = .bearer

        #expect(draft.hasSameContent(as: AuthDraft(bearer)))
        #expect(draft.credentialWrites(heldBy: bearer).isEmpty)
    }

    @Test("A changed credential is written under its reference")
    func changedCredentialIsWritten() {
        var draft = AuthDraft(basic)

        draft.setCredential("new", for: Self.password)

        #expect(draft.credentialWrites(heldBy: basic) == [CredentialWrite(reference: Self.password, value: "new")])
    }

    @Test("An untouched credential writes nothing", arguments: [
        Auth.basic(BasicAuth(username: "ada", password: password)),
        .bearer(BearerAuth(token: token)),
        .inherit,
        .none
    ] + unsupported)
    func untouchedCredentialWritesNothing(auth: Auth) {
        #expect(AuthDraft(auth).credentialWrites(heldBy: auth).isEmpty)
    }

    @Test("A cleared password is saved, because Basic can send a username alone")
    func clearedPasswordIsSaved() {
        var draft = AuthDraft(basic)

        draft.setCredential("", for: Self.password)

        #expect(draft.credentialWrites(heldBy: basic) == [CredentialWrite(reference: Self.password, value: "")])
    }

    @Test("A new Basic auth saves an empty password, so it can send a username alone")
    func newBasicSavesEmptyPassword() {
        var draft = AuthDraft(.none)

        draft.kind = .basic

        #expect(draft.credentialWrites(heldBy: .none) == [
            CredentialWrite(reference: draft.passwordReference, value: "")
        ])
    }

    @Test("A cleared token removes what is stored, because a header can't send an empty one")
    func clearedTokenIsRemoved() {
        var draft = AuthDraft(bearer)

        draft.setCredential("", for: Self.token)

        #expect(draft.credentialWrites(heldBy: bearer) == [CredentialWrite(reference: Self.token, value: nil)])
    }

    @Test("A new Bearer auth with no token saves nothing")
    func newBearerWithNoTokenSavesNothing() {
        var draft = AuthDraft(.none)

        draft.kind = .bearer

        #expect(draft.credentialWrites(heldBy: .none).isEmpty)
    }

}
