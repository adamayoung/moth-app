//  RequestDraftsAWSSignatureTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestDraftsAWSSignatureTests: RequestDraftsTesting {

    @Test("AWS Signature's three credentials reach the secret store under their references, and no row holds them")
    func awsSignatureReachesTheSecretStore() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request")
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { draft in
            draft.auth.kind = .awsSigV4
            draft.auth.awsSigV4.region = "eu-west-2"
            draft.auth.awsSigV4.service = "s3"
            draft.auth.setCredential("access-value", for: draft.auth.awsSigV4.accessKeyReference)
            draft.auth.setCredential("secret-value", for: draft.auth.awsSigV4.secretKeyReference)
            draft.auth.setCredential("session-value", for: draft.auth.awsSigV4.sessionTokenReference)
        }
        let edit = try #require(drafts.draft(for: request.id)?.auth.requestAuth)
        guard case .awsSigV4(let auth) = edit, let session = auth.sessionToken else {
            Issue.record("Expected AWS Signature with a session token")
            return
        }

        #expect(await drafts.save(request.id))

        #expect(secretStore.values == [
            auth.accessKeyID.identifier: "access-value",
            auth.secretAccessKey.identifier: "secret-value",
            session.identifier: "session-value"
        ])
        let row = try savedRequest(request.id, in: dataModel)
        #expect(try row.asDomain().auth == .awsSigV4(auth))
        for value in ["access-value", "secret-value", "session-value"] {
            #expect(!storedText(of: row).contains(value))
        }
    }

    @Test("Clearing AWS Signature's session token releases its stored value")
    func clearingTheSessionTokenReleasesIt() async throws {
        let secretStore = RecordingSecretStore()
        let session = SecretReference(identifier: "session")
        secretStore.save("value", for: session.identifier)
        let request = Request(name: "Request", auth: .awsSigV4(AWSSigV4Auth(
            accessKeyID: SecretReference(identifier: "access"),
            secretAccessKey: SecretReference(identifier: "secret"),
            sessionToken: session,
            region: "r",
            service: "s"
        )))
        let (_, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.auth.setCredential("", for: session) }

        #expect(await drafts.save(request.id))

        #expect(secretStore.values[session.identifier] == nil)
    }

    @Test("Each new reference a save leaves empty is read, so no field stays loading")
    func readsEveryReferenceAfterASave() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request")
        let (_, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.auth.kind = .awsSigV4 }
        let auth = try #require(drafts.draft(for: request.id)?.auth.awsSigV4)

        #expect(await drafts.save(request.id))

        #expect(drafts.credential(auth.accessKeyReference, in: request.id) == .notYetAvailable)
        #expect(drafts.credential(auth.secretKeyReference, in: request.id) == .notYetAvailable)
    }

}
