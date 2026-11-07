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
        .digest(DigestAuth(username: "ada", password: SecretReference(identifier: "digest"))),
        .oauth2(OAuth2Auth(
            grantType: .clientCredentials,
            authorizationURL: "",
            accessTokenURL: "https://example.com/token",
            callbackURL: "",
            clientID: "client",
            clientSecret: SecretReference(identifier: "client-secret"),
            scope: ""
        ))
    ]

    private let basic = Auth.basic(BasicAuth(username: "ada", password: Self.password))
    private let bearer = Auth.bearer(BearerAuth(token: Self.token))

    @Test("Each auth comes back unchanged from a draft nobody edited", arguments: [
        Auth.inherit,
        .none,
        .basic(BasicAuth(username: "ada", password: password)),
        .bearer(BearerAuth(token: token)),
        .apiKey(APIKeyAuth(name: "X-Key", value: token, location: .query))
    ] + unsupported)
    func roundTrips(auth: Auth) {
        #expect(AuthDraft(auth).requestAuth == auth)
    }

    @Test("The kinds are the editable ones, plus a stored kind the editor can't change")
    func kinds() throws {
        #expect(AuthDraft(.none).kinds == AuthKind.editable)
        let digest = try #require(Self.unsupported.first)
        #expect(AuthDraft(digest).kinds == AuthKind.editable + [.digest])
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

        let encoded = try JSONEncoder().encode(draft.requestAuth)
        #expect(try !#require(String(bytes: encoded, encoding: .utf8)).contains("s3cret"))
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

    @Test("Two typed values are different content, though they share one new reference")
    func typedValuesDiffer() {
        var first = AuthDraft(bearer)
        first.setCredential("first", for: Self.token)
        var second = first
        second.setCredential("second", for: Self.token)

        #expect(first.requestAuth == second.requestAuth)
        #expect(!first.hasSameContent(as: second))
    }

    @Test("Typing for a kind that isn't chosen is no change")
    func hiddenKindsTypingIsNoChange() {
        var draft = AuthDraft(bearer)

        draft.kind = .basic
        draft.setCredential("typed", for: draft.passwordReference)
        draft.kind = .bearer

        #expect(draft.hasSameContent(as: AuthDraft(bearer)))
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("A changed credential goes under a new reference, so a Save that fails changes nothing stored")
    func changedCredentialTakesANewReference() throws {
        var draft = AuthDraft(basic)

        draft.setCredential("new", for: Self.password)

        let write = try #require(draft.credentialWrites().first)
        #expect(draft.credentialWrites().count == 1)
        #expect(write.reference != Self.password)
        #expect(write.value == "new")
        #expect(draft.requestAuth == .basic(BasicAuth(username: "ada", password: write.reference)))
    }

    @Test("A credential changed twice keeps its new reference, so a Save tried again writes the same item")
    func changedCredentialKeepsItsNewReference() {
        var draft = AuthDraft(bearer)

        draft.setCredential("first", for: Self.token)
        let first = draft.credentialWrites().first?.reference
        draft.setCredential("second", for: Self.token)

        #expect(draft.credentialWrites() == [CredentialWrite(reference: first ?? Self.token, value: "second")])
        #expect(first != Self.token)
    }

    @Test("An untouched credential writes nothing", arguments: [
        Auth.basic(BasicAuth(username: "ada", password: password)),
        .bearer(BearerAuth(token: token)),
        .inherit,
        .none
    ] + unsupported)
    func untouchedCredentialWritesNothing(auth: Auth) {
        #expect(AuthDraft(auth).credentialWrites().isEmpty)
    }

    @Test("A cleared password is saved under a new reference, because Basic can send a username alone")
    func clearedPasswordIsSaved() throws {
        var draft = AuthDraft(basic)

        draft.setCredential("", for: Self.password)

        let write = try #require(draft.credentialWrites().first)
        #expect(write.reference != Self.password)
        #expect(write.value.isEmpty)
    }

    @Test("A new Basic auth saves an empty password, so it can send a username alone")
    func newBasicSavesEmptyPassword() {
        var draft = AuthDraft(.none)

        draft.kind = .basic

        #expect(draft.credentialWrites() == [CredentialWrite(reference: draft.passwordReference, value: "")])
    }

    @Test("A cleared token moves off its reference and writes nothing, because a header can't send an empty one")
    func clearedTokenWritesNothing() {
        var draft = AuthDraft(bearer)

        draft.setCredential("", for: Self.token)

        #expect(draft.credentialWrites().isEmpty)
        #expect(draft.requestAuth != bearer)
    }

    @Test("A new Bearer auth with no token saves nothing")
    func newBearerWithNoTokenSavesNothing() {
        var draft = AuthDraft(.none)

        draft.kind = .bearer

        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("Following what is saved takes its kind and references, and keeps what was typed for another kind")
    func followingKeepsHiddenTyping() {
        var draft = AuthDraft(.none)
        draft.kind = .basic
        draft.setCredential("typed", for: draft.passwordReference)
        draft.kind = .none

        draft.follow(AuthDraft(bearer))

        #expect(draft.requestAuth == bearer)
        #expect(draft.typedCredential(for: draft.passwordReference) == "typed")
    }

    @Test("Following a kind that had text typed for it takes what is saved, not the text")
    func followingDropsTextForTheSavedKind() {
        var draft = AuthDraft(.inherit)
        draft.kind = .bearer
        draft.setCredential("typed", for: draft.tokenReference)
        draft.kind = .inherit

        draft.follow(AuthDraft(bearer))

        #expect(draft.requestAuth == bearer)
        #expect(draft.typedCredential(for: draft.tokenReference) == nil)
    }

    @Test("Rebasing an auth the editor can't change takes the row's, so choosing it again can't undo a sync")
    func rebasingMovesAnUnsupportedAuth() {
        let older = Auth.digest(DigestAuth(username: "ada", password: Self.token))
        let newer = Auth.digest(DigestAuth(username: "ada", password: Self.password))
        var draft = AuthDraft(older)
        draft.kind = .bearer

        draft.rebaseCredentials(onto: AuthDraft(newer))
        draft.kind = .digest

        #expect(draft.requestAuth == newer)
    }

    @Test("Rebasing onto a row with no such auth stops offering it")
    func rebasingDropsAnUnsupportedAuthTheRowLost() {
        var draft = AuthDraft(.digest(DigestAuth(username: "ada", password: Self.token)))

        draft.rebaseCredentials(onto: AuthDraft(.none))

        #expect(draft.kinds == AuthKind.editable)
        #expect(draft.requestAuth == .none)
    }

    @Test("Rebasing an edited auth takes the row's references, and keeps its kind and username")
    func rebasingTakesTheRowsReferences() {
        let newer = SecretReference(identifier: "newer")
        var draft = AuthDraft(basic)
        draft.username = "grace"

        draft.rebaseCredentials(onto: AuthDraft(.basic(BasicAuth(username: "ada", password: newer))))

        #expect(draft.requestAuth == .basic(BasicAuth(username: "grace", password: newer)))
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("Rebasing onto a row that holds a reference this draft minted mints another, so nothing writes over it")
    func rebasingNeverReusesAHeldReference() throws {
        var draft = AuthDraft(bearer)
        draft.setCredential("first", for: Self.token)
        let saved = AuthDraft(draft.requestAuth)

        draft.rebaseCredentials(onto: saved)
        draft.setCredential("second", for: draft.tokenReference)

        let write = try #require(draft.credentialWrites().first)
        #expect(write.reference != saved.tokenReference)
    }

}
