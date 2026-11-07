//  AWSSigV4DraftTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct AWSSigV4DraftTests {

    private nonisolated static let accessKey = SecretReference(identifier: "access")
    private nonisolated static let secretKey = SecretReference(identifier: "secret")
    private nonisolated static let sessionToken = SecretReference(identifier: "token")

    private nonisolated static let stored = Auth.awsSigV4(AWSSigV4Auth(
        accessKeyID: accessKey,
        secretAccessKey: secretKey,
        sessionToken: sessionToken,
        region: "eu-west-2",
        service: "s3"
    ))

    private func sigV4(of draft: AuthDraft) throws -> AWSSigV4Auth {
        guard case .awsSigV4(let sigV4) = draft.requestAuth else {
            throw AWSSigV4DraftError.notAWSSignature
        }
        return sigV4
    }

    private func typedDraft() -> AuthDraft {
        var draft = AuthDraft(.none)
        draft.kind = .awsSigV4
        draft.awsSigV4.region = "eu-west-2"
        draft.awsSigV4.service = "s3"
        draft.setCredential("AKID", for: draft.awsSigV4.accessKeyReference)
        draft.setCredential("shh", for: draft.awsSigV4.secretKeyReference)
        draft.setCredential("tok", for: draft.awsSigV4.sessionTokenReference)
        return draft
    }

    @Test("The picker offers AWS Signature")
    func offered() {
        #expect(AuthDraft(.none).kinds.contains(.awsSigV4))
        #expect(AuthKind.editable.contains(.awsSigV4))
    }

    @Test("A stored auth comes back unchanged, and writes nothing", arguments: [
        stored,
        .awsSigV4(AWSSigV4Auth(accessKeyID: accessKey, secretAccessKey: secretKey, region: "r", service: "s"))
    ])
    func roundTrips(auth: Auth) {
        let draft = AuthDraft(auth)

        #expect(draft.kind == .awsSigV4)
        #expect(draft.requestAuth == auth)
        #expect(draft.credentialWrites().isEmpty)
        #expect(draft.hasSameContent(as: AuthDraft(auth)))
    }

    @Test("Typed credentials go to the writes, under the references the row takes, and not to the row")
    func typedCredentials() throws {
        let draft = typedDraft()
        let sigV4 = try sigV4(of: draft)

        #expect(try Set(draft.credentialWrites()) == [
            CredentialWrite(reference: sigV4.accessKeyID, value: "AKID"),
            CredentialWrite(reference: sigV4.secretAccessKey, value: "shh"),
            CredentialWrite(reference: #require(sigV4.sessionToken), value: "tok")
        ])
        let row = try String(bytes: JSONEncoder().encode(draft.requestAuth), encoding: .utf8)
        for credential in ["AKID", "shh", "tok"] {
            #expect(row?.contains(credential) == false)
        }
        #expect(sigV4.region == "eu-west-2")
        #expect(sigV4.service == "s3")
    }

    @Test("Every credential's reference is one to load")
    func referencesToLoad() {
        let draft = AuthDraft(Self.stored)

        #expect(draft.credentialReferences == [Self.accessKey, Self.secretKey, Self.sessionToken])
    }

    @Test("A session token left alone has no reference")
    func noSessionToken() throws {
        var draft = typedDraft()
        draft.setCredential("", for: draft.awsSigV4.sessionTokenReference)

        #expect(try sigV4(of: draft).sessionToken == nil)
        #expect(draft.credentialWrites().count == 2)
    }

    @Test("Clearing a stored session token drops its reference, so the old item is released")
    func clearingSessionToken() throws {
        var draft = AuthDraft(Self.stored)

        draft.setCredential("", for: Self.sessionToken)

        #expect(try sigV4(of: draft).sessionToken == nil)
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("A cleared access key moves off its reference and writes nothing, so the build reports it")
    func clearingAccessKey() throws {
        var draft = AuthDraft(Self.stored)

        draft.setCredential("", for: Self.accessKey)

        #expect(try sigV4(of: draft).accessKeyID != Self.accessKey)
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("A changed credential goes under a new reference, so a Save that fails changes nothing stored")
    func changedCredential() throws {
        var draft = AuthDraft(Self.stored)

        draft.setCredential("new", for: Self.secretKey)

        let sigV4 = try sigV4(of: draft)
        #expect(sigV4.secretAccessKey != Self.secretKey)
        #expect(sigV4.accessKeyID == Self.accessKey)
        #expect(draft.credentialWrites() == [CredentialWrite(reference: sigV4.secretAccessKey, value: "new")])
    }

    @Test("A credential changed twice keeps its new reference, so a Save tried again writes the same item")
    func changedTwice() throws {
        var draft = AuthDraft(Self.stored)
        draft.setCredential("one", for: Self.secretKey)
        let first = try sigV4(of: draft).secretAccessKey

        draft.setCredential("two", for: Self.secretKey)

        #expect(try sigV4(of: draft).secretAccessKey == first)
    }

    @Test("The typed text is read back for its field")
    func readsTypedText() {
        let draft = typedDraft()

        #expect(draft.typedCredential(for: draft.awsSigV4.accessKeyReference) == "AKID")
        #expect(draft.typedCredential(for: draft.awsSigV4.secretKeyReference) == "shh")
        #expect(draft.typedCredential(for: draft.awsSigV4.sessionTokenReference) == "tok")
    }

    @Test("Text typed back to what is stored leaves nothing to save")
    func discardsMatchingText() {
        var draft = AuthDraft(Self.stored)
        draft.setCredential("same", for: Self.accessKey)

        draft.discardCredentials { reference, text in reference == Self.accessKey && text == "same" }

        #expect(draft.typedCredential(for: Self.accessKey) == nil)
        #expect(draft.hasSameContent(as: AuthDraft(Self.stored)))
    }

    @Test("Two typed values are different content, though they share one new reference")
    func typedTextIsContent() {
        var first = AuthDraft(Self.stored)
        first.setCredential("one", for: Self.secretKey)
        var second = first
        second.setCredential("two", for: Self.secretKey)

        #expect(!first.hasSameContent(as: second))
    }

    @Test("A region and a service are part of the content")
    func fieldsAreContent() {
        var region = AuthDraft(Self.stored)
        region.awsSigV4.region = "us-east-1"
        var service = AuthDraft(Self.stored)
        service.awsSigV4.service = "execute-api"

        #expect(!region.hasSameContent(as: AuthDraft(Self.stored)))
        #expect(!service.hasSameContent(as: AuthDraft(Self.stored)))
    }

    @Test("Typing for AWS Signature while another kind is chosen is no change")
    func otherKindIsNoChange() {
        var draft = AuthDraft(.none)
        draft.setCredential("typed", for: draft.awsSigV4.accessKeyReference)
        draft.awsSigV4.region = "typed"

        #expect(draft.hasSameContent(as: AuthDraft(.none)))
    }

    @Test("Following what is saved takes its fields and drops what was typed")
    func follows() {
        var draft = typedDraft()

        draft.follow(AuthDraft(Self.stored))

        #expect(draft.requestAuth == Self.stored)
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("Rebasing an edited auth takes the row's references, and keeps its fields and text")
    func rebases() {
        var draft = typedDraft()

        draft.rebaseCredentials(onto: AuthDraft(Self.stored))

        #expect(draft.awsSigV4.accessKeyReference == Self.accessKey)
        #expect(draft.awsSigV4.sessionTokenReference == Self.sessionToken)
        #expect(draft.typedCredential(for: Self.accessKey) == "AKID")
        #expect(draft.awsSigV4.region == "eu-west-2")
    }

    @Test("Rebasing onto a row that holds a reference this draft minted mints another, so nothing writes over it")
    func rebaseMintsNewReferences() throws {
        var draft = typedDraft()
        let minted = try sigV4(of: draft).secretAccessKey

        draft.rebaseCredentials(onto: AuthDraft(draft.requestAuth))

        #expect(draft.awsSigV4.secretKeyReference == minted)
        #expect(try sigV4(of: draft).secretAccessKey != minted)
    }

}

private nonisolated enum AWSSigV4DraftError: Error {

    case notAWSSignature

}
