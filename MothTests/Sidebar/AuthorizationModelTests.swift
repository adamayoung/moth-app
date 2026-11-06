//  AuthorizationModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct AuthorizationModelTests {

    private struct KeychainRefused: Error {}

    private struct RefusingSecretStore: SecretStore {
        func save(_: String, for _: String) async throws {
            throw KeychainRefused()
        }

        func value(for _: String) async throws -> String? {
            nil
        }

        func removeValue(for _: String) async throws {}
    }

    private let token = SecretReference(identifier: "token")
    private let folder: Folder
    private let collection: RequestCollection
    private let dataModel: DataModel

    init() throws {
        let folder = Folder(id: UUID(), name: "Users")
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(folder))
        ])
        self.folder = folder
        self.collection = collection
        self.dataModel = try .inMemory(seed: Workspace(collections: [collection]))
    }

    private func bearer(_ token: SecretReference) -> Auth {
        .bearer(BearerAuth(token: token))
    }

    private func model(
        of container: TreeContainerID,
        holding auth: Auth,
        secretStore: any SecretStore
    ) -> AuthorizationModel {
        let target = AuthorizationSheetTarget(container: container, title: "Users", auth: auth, inherited: .nothing)
        return SidebarModel(writer: dataModel.writer, secretStore: secretStore).authorizationModel(for: target)
    }

    private func savedFolder() throws -> FolderModel {
        try #require(ModelContext(dataModel.container).fetch(FetchDescriptor<FolderModel>()).first)
    }

    private func savedCollection() throws -> CollectionModel {
        try #require(ModelContext(dataModel.container).fetch(FetchDescriptor<CollectionModel>()).first)
    }

    @Test("A folder's token reaches the secret store under its reference, and no row holds it")
    func savesAFolder() async throws {
        let secretStore = RecordingSecretStore()
        let model = model(of: .folder(folder.id), holding: .inherit, secretStore: secretStore)
        model.update { draft in
            draft.kind = .bearer
            draft.setCredential("s3cret-token", for: draft.tokenReference)
        }

        #expect(await model.save())

        let reference = model.draft.tokenReference
        #expect(secretStore.values == [reference.identifier: "s3cret-token"])
        let row = try savedFolder()
        #expect(try row.asDomain().auth == bearer(reference))
        let authJSON = try #require(row.authData)
        #expect(try !#require(String(bytes: authJSON, encoding: .utf8)).contains("s3cret-token"))
    }

    @Test("A collection's auth is saved")
    func savesACollection() async throws {
        let model = model(of: .collection(collection.id), holding: .none, secretStore: RecordingSecretStore())
        model.update { draft in
            draft.kind = .basic
            draft.username = "ada"
        }

        #expect(await model.save())

        let saved = try savedCollection().asDomain().auth
        #expect(saved == .basic(BasicAuth(username: "ada", password: model.draft.passwordReference)))
    }

    @Test("A stored credential loads into its field, and typing it back leaves nothing to save")
    func loadsAStoredCredential() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let model = model(of: .folder(folder.id), holding: bearer(token), secretStore: secretStore)
        #expect(model.credential(token) == .loading)

        await model.loadCredential(token)
        #expect(model.credential(token) == .available("stored"))

        model.update { $0.setCredential("stored", for: token) }
        #expect(model.draft.typedCredential(for: token) == nil)
    }

    @Test("A sheet with no change closes without writing")
    func noChangeWritesNothing() async {
        let secretStore = RecordingSecretStore()
        let model = model(of: .folder(UUID()), holding: .inherit, secretStore: secretStore)

        #expect(await model.save())

        #expect(secretStore.values.isEmpty)
        #expect(!model.saveFailed)
    }

    @Test("A value the store refuses keeps the sheet open, and leaves the row as it was")
    func refusedValueFails() async throws {
        let model = model(of: .folder(folder.id), holding: .inherit, secretStore: RefusingSecretStore())
        model.update { draft in
            draft.kind = .bearer
            draft.setCredential("typed", for: draft.tokenReference)
        }

        #expect(await !model.save())

        #expect(model.saveFailed)
        #expect(!model.isSaving)
        #expect(try savedFolder().asDomain().auth == .inherit)
    }

    @Test("Credentials that moved on while the sheet was open refuse the Save")
    func staleCredentialsFail() async {
        let secretStore = RecordingSecretStore()
        let model = model(of: .folder(folder.id), holding: bearer(token), secretStore: secretStore)
        model.update { $0.kind = .none }

        #expect(await !model.save())

        #expect(model.saveFailed)
    }

    @Test("A replaced credential leaves the secret store once the row has moved on")
    func replacedCredentialIsRemoved() async throws {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        try await dataModel.writer.updateAuth(of: .folder(folder.id), to: bearer(token), replacing: .inherit)
        let model = model(of: .folder(folder.id), holding: bearer(token), secretStore: secretStore)
        model.update { $0.kind = .none }

        #expect(await model.save())

        #expect(secretStore.values.isEmpty)
        #expect(try savedFolder().asDomain().auth == Auth.none)
    }

    @Test("A second Save after one that worked leaves the credential the row now holds")
    func secondSaveKeepsTheCredential() async throws {
        let secretStore = RecordingSecretStore()
        secretStore.save("old", for: token.identifier)
        try await dataModel.writer.updateAuth(of: .folder(folder.id), to: bearer(token), replacing: .inherit)
        let model = model(of: .folder(folder.id), holding: bearer(token), secretStore: secretStore)
        model.update { $0.setCredential("new", for: token) }

        #expect(await model.save())
        _ = await model.save()

        guard case .bearer(let saved) = try savedFolder().asDomain().auth else {
            Issue.record("The folder should hold Bearer auth")
            return
        }
        #expect(secretStore.values == [saved.token.identifier: "new"])
    }

    @Test("A Save writes the auth it was pressed with, whatever changes while it runs")
    func saveWritesTheAuthItStartedWith() async throws {
        let secretStore = HoldingSecretStore()
        let model = model(of: .folder(folder.id), holding: .inherit, secretStore: secretStore)
        model.update { draft in
            draft.kind = .bearer
            draft.setCredential("typed", for: draft.tokenReference)
        }
        let reference = model.draft.tokenReference
        await secretStore.holdNextSave()
        let save = Task { await model.save() }
        for _ in 0 ..< 100_000 where await !secretStore.isHoldingASave {
            await Task.yield()
        }

        model.update { $0.kind = .none }
        await secretStore.finishHeldSave()

        #expect(await save.value)
        #expect(try savedFolder().asDomain().auth == bearer(reference))
    }

    @Test("The sheet opens on a container's auth, saying what it would inherit")
    func presentsAContainer() throws {
        let sidebar = SidebarModel(writer: dataModel.writer, secretStore: RecordingSecretStore())
        let context = dataModel.mainContext
        let tree = try CollectionTree(
            collections: context.fetch(FetchDescriptor<CollectionModel>()),
            folders: context.fetch(FetchDescriptor<FolderModel>()),
            requests: context.fetch(FetchDescriptor<RequestModel>())
        )
        sidebar.treeDidChange(tree)

        try sidebar.presentAuthorization(of: #require(tree.node(.folder(folder.id))))

        let target = try #require(sidebar.presentedAuthorization)
        #expect(target.container == .folder(folder.id))
        #expect(target.title == "Users")
        #expect(target.auth == .inherit)
        #expect(target.inherited == .nothing)
    }

}
