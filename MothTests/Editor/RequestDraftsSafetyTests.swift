//  RequestDraftsSafetyTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

/// Each test is a way a Save could lose what someone stored.
@MainActor
struct RequestDraftsSafetyTests: RequestDraftsTesting {

    private struct WriteRefused: Error {}

    private let password = SecretReference(identifier: "password")
    private let newerPassword = SecretReference(identifier: "newer-password")
    private let token = SecretReference(identifier: "token")

    private func basic(_ username: String, _ password: SecretReference) -> Auth {
        .basic(BasicAuth(username: username, password: password))
    }

    /// A row written behind the draft, as a sync that has landed but not been delivered leaves it.
    private func syncBehindTheDraft(
        _ request: Request,
        to synced: Request,
        in dataModel: DataModel
    ) async throws {
        try await dataModel.writer.updateRequest(request.id, with: RequestEdit(synced), from: RequestEdit(request))
    }

    @Test("A password from a Save that failed is the one a retry stores, not an empty one")
    func retryKeepsAFailedPassword() async {
        let secretStore = RecordingSecretStore()
        var failsNextWrite = true
        var written: Auth?
        let drafts = RequestDrafts(secretStore: secretStore) { _, edit, _ in
            if failsNextWrite {
                failsNextWrite = false
                throw WriteRefused()
            }
            written = edit.auth
            return []
        }
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { draft in
            draft.auth.kind = .basic
            draft.auth.setCredential("abc", for: draft.auth.passwordReference)
        }
        #expect(await !drafts.save(request.id))

        drafts.update(request.id) { $0.url = "https://example.com" }
        #expect(await drafts.save(request.id))

        guard case .basic(let saved) = written else {
            Issue.record("The retry should have written Basic auth")
            return
        }
        #expect(secretStore.values[saved.password.identifier] == "abc")
    }

    @Test("A username edit under a synced password keeps the synced password")
    func usernameEditKeepsASyncedPassword() async throws {
        let secretStore = RecordingSecretStore()
        secretStore.save("old", for: password.identifier)
        secretStore.save("newer", for: newerPassword.identifier)
        let request = Request(name: "Request", auth: basic("ada", password))
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.auth.username = "grace" }
        var synced = request
        synced.auth = basic("ada", newerPassword)
        try await syncBehindTheDraft(request, to: synced, in: dataModel)
        drafts.savedRequestDidChange(synced)

        #expect(await drafts.save(request.id))

        #expect(try savedRequest(request.id, in: dataModel).asDomain().auth == basic("grace", newerPassword))
        #expect(secretStore.values[newerPassword.identifier] == "newer")
    }

    @Test("A Save that fails leaves the stored credential as it was, and Revert finds it there")
    func failedSaveLeavesTheStoredCredential() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("old", for: token.identifier)
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in throw WriteRefused() }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        await drafts.loadCredential(token, in: request.id)
        drafts.update(request.id) { $0.auth.setCredential("new", for: token) }

        #expect(await !drafts.save(request.id))
        #expect(drafts.isEdited(request.id))
        drafts.revert(request.id)

        #expect(secretStore.values == [token.identifier: "old"])
        #expect(drafts.credential(token, in: request.id) == .available("old"))
    }

    @Test("Choosing a kind again during a Save that releases its credential leaves nothing pointing at the gone value")
    func togglingDuringASaveLeavesNoDanglingReference() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: password.identifier)
        var drafts: RequestDrafts?
        let request = Request(name: "Request", auth: basic("ada", password))
        let model = RequestDrafts(secretStore: secretStore) { [password] id, _, _ in
            drafts?.update(id) { $0.auth.kind = .basic }
            return [password]
        }
        drafts = model
        model.savedRequestDidChange(request)
        model.update(request.id) { $0.auth.kind = .none }

        #expect(await model.save(request.id))

        let reference = model.draft(for: request.id)?.auth.passwordReference
        #expect(reference != password)
        #expect(secretStore.values.isEmpty)
    }

    @Test("A body nobody touched stays what a sync wrote, though the draft has not heard of it yet")
    func untouchedBodyKeepsAnUndeliveredSync() async throws {
        let theirs = RequestBody.raw(content: "theirs", contentType: "text/plain")
        let request = Request(name: "Request", body: .raw(content: "old", contentType: "text/plain"))
        let (dataModel, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.url = "https://example.com" }
        var synced = request
        synced.body = theirs
        try await syncBehindTheDraft(request, to: synced, in: dataModel)

        #expect(await drafts.save(request.id))

        let saved = try savedRequest(request.id, in: dataModel).asDomain()
        #expect(saved.urlTemplate == "https://example.com")
        #expect(saved.body == theirs)
    }

    @Test("An auth nobody touched stays what a sync wrote, and the Save isn't refused for it")
    func untouchedAuthKeepsAnUndeliveredSync() async throws {
        let request = Request(name: "Request", auth: basic("ada", password))
        let (dataModel, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.url = "https://example.com" }
        var synced = request
        synced.auth = basic("grace", newerPassword)
        try await syncBehindTheDraft(request, to: synced, in: dataModel)

        #expect(await drafts.save(request.id))

        let saved = try savedRequest(request.id, in: dataModel).asDomain()
        #expect(saved.urlTemplate == "https://example.com")
        #expect(saved.auth == synced.auth)
    }

    @Test("A delivery keeps what was typed for a body kind that isn't chosen")
    func deliveryKeepsHiddenBodyFields() {
        let drafts = RequestDrafts.preview
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { draft in
            draft.body.kind = .raw
            draft.body.rawContent = "typed"
            draft.body.kind = .none
            draft.url = "https://example.com/mine"
        }
        var synced = request
        synced.name = "Renamed"
        synced.headers = [KeyValue(key: "Accept", value: "text/plain")]

        drafts.savedRequestDidChange(synced)
        drafts.update(request.id) { $0.body.kind = .raw }

        #expect(drafts.draft(for: request.id)?.body.rawContent == "typed")
    }

    @Test("A delivery keeps what was typed for a body kind that isn't chosen, with nothing else edited")
    func deliveryKeepsHiddenBodyFieldsOfACleanDraft() {
        let drafts = RequestDrafts.preview
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { draft in
            draft.body.kind = .raw
            draft.body.rawContent = "typed"
            draft.body.kind = .none
        }
        #expect(!drafts.isEdited(request.id))
        var synced = request
        synced.headers = [KeyValue(key: "Accept", value: "text/plain")]

        drafts.savedRequestDidChange(synced)
        drafts.update(request.id) { $0.body.kind = .raw }

        #expect(drafts.draft(for: request.id)?.body.rawContent == "typed")
    }

    @Test("A delivery keeps a password typed for an auth kind that isn't chosen")
    func deliveryKeepsHiddenCredential() throws {
        let drafts = RequestDrafts.preview
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { draft in
            draft.auth.kind = .basic
            draft.auth.setCredential("typed", for: draft.auth.passwordReference)
            draft.auth.kind = .inherit
        }
        var synced = request
        synced.headers = [KeyValue(key: "Accept", value: "text/plain")]

        drafts.savedRequestDidChange(synced)

        let reference = try #require(drafts.draft(for: request.id)?.auth.passwordReference)
        #expect(drafts.draft(for: request.id)?.auth.typedCredential(for: reference) == "typed")
    }

}
