//  StoreWriterAuthTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterAuthTests {

    private let oldToken = SecretReference(identifier: "old-token")
    private let newToken = SecretReference(identifier: "new-token")

    private func bearer(_ token: SecretReference) -> Auth {
        .bearer(BearerAuth(token: token))
    }

    private func edit(auth: Auth) -> RequestEdit {
        RequestEdit(auth: auth)
    }

    private func dataModel(holding request: Request) throws -> DataModel {
        try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        )
    }

    private func savedAuth(of id: Request.ID, in dataModel: DataModel) throws -> Auth {
        try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first { $0.id == id }).asDomain().auth
    }

    private func addTwin(of request: Request, auth: Auth, to dataModel: DataModel) throws {
        var twin = request
        twin.auth = auth
        let context = ModelContext(dataModel.container)
        try context.insert(RequestModel(twin, sortOrder: 1))
        try context.save()
    }

    @Test("A Save refuses a row whose credentials have moved on since the draft read them")
    func refusesStaleCredentials() async throws {
        let request = Request(name: "Request", auth: bearer(newToken))
        let dataModel = try dataModel(holding: request)

        await #expect(throws: AuthWriteError.credentialsChanged) {
            try await dataModel.writer.updateRequest(
                request.id,
                with: edit(auth: .none),
                from: edit(auth: bearer(oldToken))
            )
        }

        #expect(try savedAuth(of: request.id, in: dataModel) == bearer(newToken))
    }

    @Test("A username another Mac changed is no reason to refuse, because no credential has moved")
    func acceptsAChangedUsername() async throws {
        let password = SecretReference(identifier: "password")
        let theirs = Auth.basic(BasicAuth(username: "theirs", password: password))
        let mine = Auth.basic(BasicAuth(username: "mine", password: password))
        let request = Request(name: "Request", auth: theirs)
        let dataModel = try dataModel(holding: request)

        try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: mine),
            from: edit(auth: .basic(BasicAuth(username: "old", password: password)))
        )

        #expect(try savedAuth(of: request.id, in: dataModel) == mine)
    }

    @Test("A Save accepts twin rows when any of them holds what the draft read")
    func acceptsATwinHoldingTheCredential() async throws {
        let request = Request(name: "Request", auth: bearer(oldToken))
        let dataModel = try dataModel(holding: request)
        try addTwin(of: request, auth: bearer(newToken), to: dataModel)

        let released = try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: .none),
            from: edit(auth: bearer(oldToken))
        )

        #expect(released == [oldToken, newToken])
    }

    @Test("Replacing a credential releases its reference")
    func replacingReleases() async throws {
        let request = Request(name: "Request", auth: bearer(oldToken))
        let dataModel = try dataModel(holding: request)

        let released = try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: bearer(newToken)),
            from: edit(auth: bearer(oldToken))
        )

        #expect(released == [oldToken])
        #expect(try savedAuth(of: request.id, in: dataModel) == bearer(newToken))
    }

    @Test("Keeping a credential releases nothing")
    func keepingReleasesNothing() async throws {
        let request = Request(name: "Request", auth: bearer(oldToken))
        let dataModel = try dataModel(holding: request)

        let released = try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: bearer(oldToken)),
            from: edit(auth: bearer(oldToken))
        )

        #expect(released.isEmpty)
    }

    @Test("A credential another request holds isn't released")
    func anotherRequestKeepsTheCredential() async throws {
        let request = Request(name: "Request", auth: bearer(oldToken))
        let other = Request(name: "Other", auth: bearer(oldToken))
        let dataModel = try TreeFixtures.dataModel(holding: RequestCollection(name: "API", children: [
            TreeFixtures.item(0, request),
            TreeFixtures.item(1, other)
        ]))

        let released = try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: .none),
            from: edit(auth: bearer(oldToken))
        )

        #expect(released.isEmpty)
    }

    @Test("A credential a folder or collection holds isn't released")
    func containersKeepTheCredential() async throws {
        let request = Request(name: "Request", auth: bearer(oldToken))
        let folderRequest = Request(name: "In a Folder", auth: bearer(newToken))
        let folder = Folder(name: "Users", auth: bearer(oldToken), children: [TreeFixtures.item(0, folderRequest)])
        let collection = RequestCollection(name: "API", auth: bearer(newToken), children: [
            TreeFixtures.item(0, request),
            TreeFixtures.item(1, folder)
        ])
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        let keptByFolder = try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: .none),
            from: edit(auth: bearer(oldToken))
        )
        let keptByCollection = try await dataModel.writer.updateRequest(
            folderRequest.id,
            with: edit(auth: .none),
            from: edit(auth: bearer(newToken))
        )

        #expect(keptByFolder.isEmpty)
        #expect(keptByCollection.isEmpty)
    }

    @Test("A credential a row this build can't read may hold isn't released")
    func unreadableRowKeepsTheCredential() async throws {
        let request = Request(name: "Request", auth: bearer(oldToken))
        let other = Request(name: "Other")
        let dataModel = try TreeFixtures.dataModel(holding: RequestCollection(name: "API", children: [
            TreeFixtures.item(0, request),
            TreeFixtures.item(1, other)
        ]))
        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(RequestModel.withID(other.id)).first)
        row.authData = Data(#"{"futureKind":{"key":"\#(oldToken.identifier)"}}"#.utf8)
        try context.save()

        let released = try await dataModel.writer.updateRequest(
            request.id,
            with: edit(auth: .none),
            from: edit(auth: bearer(oldToken))
        )

        #expect(released.isEmpty)
    }

    @Test("A Save that leaves the body and auth alone keeps their stored bytes, including keys this build can't read")
    func untouchedFieldsKeepTheirBytes() async throws {
        let request = Request(
            name: "Request",
            body: .graphQL(query: "{ me }", variables: "{}"),
            auth: .digest(DigestAuth(username: "ada", password: oldToken))
        )
        let dataModel = try dataModel(holding: request)
        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(RequestModel.withID(request.id)).first)
        let authJSON = try #require(row.authData.flatMap { String(bytes: $0, encoding: .utf8) })
        let bodyJSON = try #require(row.bodyData.flatMap { String(bytes: $0, encoding: .utf8) })
        let auth = Data(authJSON.replacingOccurrences(of: "\"username\"", with: "\"future\":1,\"username\"").utf8)
        let body = Data(bodyJSON.replacingOccurrences(of: "\"query\"", with: "\"future\":1,\"query\"").utf8)
        row.authData = auth
        row.bodyData = body
        try context.save()
        var draft = RequestDraft(request)
        draft.url = "https://example.com"

        let released = try await dataModel.writer.updateRequest(
            request.id,
            with: draft.edit,
            from: RequestEdit(request)
        )

        let after = try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first)
        #expect(after.urlTemplate == "https://example.com")
        #expect(after.bodyData == body)
        #expect(after.authData == auth)
        #expect(released.isEmpty)
    }

    @Test("A body and auth the draft didn't change stay as a sync left them, with no refusal")
    func untouchedFieldsKeepASync() async throws {
        let theirBody = RequestBody.raw(content: "theirs", contentType: "text/plain")
        let request = Request(name: "Request", body: theirBody, auth: bearer(newToken))
        let dataModel = try dataModel(holding: request)
        let base = RequestEdit(body: .none, auth: bearer(oldToken))
        var edit = base
        edit.urlTemplate = "https://example.com"

        let released = try await dataModel.writer.updateRequest(request.id, with: edit, from: base)

        let saved = try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first).asDomain()
        #expect(saved.urlTemplate == "https://example.com")
        #expect(saved.body == theirBody)
        #expect(saved.auth == bearer(newToken))
        #expect(released.isEmpty)
    }

    @Test("A row typed back in is no change to the body, so what a sync wrote stays")
    func retypedRowKeepsASyncedBody() async throws {
        let theirBody = RequestBody.raw(content: "theirs", contentType: "text/plain")
        let request = Request(name: "Request", body: theirBody)
        let dataModel = try dataModel(holding: request)
        let base = RequestEdit(body: .urlEncoded([KeyValue(key: "a", value: "b")]))
        let edit = RequestEdit(body: .urlEncoded([KeyValue(key: "a", value: "b")]))

        try await dataModel.writer.updateRequest(request.id, with: edit, from: base)

        let saved = try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first).asDomain()
        #expect(saved.body == theirBody)
    }

}
