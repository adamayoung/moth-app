//  StoreWriterContainerAuthTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterContainerAuthTests {

    private let oldToken = SecretReference(identifier: "old-token")
    private let newToken = SecretReference(identifier: "new-token")

    private func bearer(_ token: SecretReference) -> Auth {
        .bearer(BearerAuth(token: token))
    }

    @Test("Setting a folder's auth writes it, and releases what it replaces")
    func updatesAFolder() async throws {
        let folder = Folder(name: "Users", auth: bearer(oldToken))
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, folder)])
        )

        let released = try await dataModel.writer.updateAuth(
            of: .folder(folder.id),
            to: bearer(newToken),
            replacing: bearer(oldToken)
        )

        let saved = try #require(TreeFixtures.savedRows(FolderModel.self, in: dataModel).first).asDomain()
        #expect(saved.auth == bearer(newToken))
        #expect(released == [oldToken])
    }

    @Test("Setting a collection's auth writes every row with the identifier, because sync can duplicate one")
    func updatesACollectionAndItsTwin() async throws {
        let collection = RequestCollection(name: "API", auth: .none)
        let dataModel = try TreeFixtures.dataModel(holding: collection)
        let context = ModelContext(dataModel.container)
        try context.insert(CollectionModel(collection, sortOrder: 1))
        try context.save()

        try await dataModel.writer.updateAuth(of: .collection(collection.id), to: bearer(newToken), replacing: .none)

        let rows = try TreeFixtures.savedRows(CollectionModel.self, in: dataModel)
        #expect(rows.count == 2)
        #expect(try rows.allSatisfy { try $0.asDomain().auth == bearer(newToken) })
    }

    @Test("Setting a container's auth refuses credentials that have moved on")
    func refusesAStaleContainer() async throws {
        let folder = Folder(name: "Users", auth: bearer(newToken))
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, folder)])
        )

        await #expect(throws: AuthWriteError.credentialsChanged) {
            try await dataModel.writer.updateAuth(of: .folder(folder.id), to: .none, replacing: bearer(oldToken))
        }
    }

    @Test("Setting the auth of a container that has gone reports it")
    func containerHasGone() async throws {
        let dataModel = try TreeFixtures.dataModel(holding: RequestCollection(name: "API"))
        let missing = TreeContainerID.folder(UUID())

        await #expect(throws: TreeWriteError.containerNotFound(missing)) {
            try await dataModel.writer.updateAuth(of: missing, to: .none, replacing: .inherit)
        }
    }

    @Test("Setting a container's auth refuses stored auth this build can't read")
    func refusesAnUnreadableContainer() async throws {
        let folder = Folder(name: "Users")
        let dataModel = try TreeFixtures.dataModel(
            holding: RequestCollection(name: "API", children: [TreeFixtures.item(0, folder)])
        )
        let unreadable = Data("not JSON".utf8)
        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(FolderModel.withID(folder.id)).first)
        row.authData = unreadable
        try context.save()

        await #expect(throws: (any Error).self) {
            try await dataModel.writer.updateAuth(of: .folder(folder.id), to: .none, replacing: .inherit)
        }

        #expect(try TreeFixtures.savedRows(FolderModel.self, in: dataModel).first?.authData == unreadable)
    }

}
