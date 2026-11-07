//  SendContextTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct SendContextTests {

    private let bearer = Auth.bearer(BearerAuth(token: SecretReference(identifier: "token")))
    private let request = Request(name: "List", urlTemplate: "https://example.com")

    /// Collection "API" > Folder "Users" > request.
    private func tree(collection: Auth = .none, folder: Auth = .inherit) throws -> (DataModel, CollectionTree) {
        let folder = Folder(name: "Users", auth: folder, children: [TreeFixtures.item(0, request)])
        let dataModel = try TreeFixtures.dataModel(holding: RequestCollection(
            name: "API",
            auth: collection,
            children: [TreeFixtures.item(0, folder)]
        ))
        return try (dataModel, CollectionTree(savedIn: dataModel))
    }

    @Test("Effective auth is the nearest container's that sets one")
    func effectiveAuth() throws {
        let (_, tree) = try tree(collection: bearer)

        #expect(try tree.effectiveAuth(of: .request(request.id)) == bearer)
    }

    @Test("A folder set to No Auth stops the walk")
    func noAuthStops() throws {
        let (_, tree) = try tree(collection: bearer, folder: .none)

        #expect(try tree.effectiveAuth(of: .request(request.id)) == Auth.none)
    }

    @Test("A collection that inherits leaves no auth")
    func nothingAbove() throws {
        let (_, tree) = try tree(collection: .inherit)

        #expect(try tree.effectiveAuth(of: .request(request.id)) == Auth.none)
    }

    @Test("A container that can't be read refuses, because sending without its auth would hide that")
    func unreadableContainer() throws {
        let (dataModel, _) = try tree()
        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(FetchDescriptor<FolderModel>()).first)
        row.authData = Data("not JSON".utf8)
        try context.save()
        let tree = try CollectionTree(savedIn: dataModel)

        #expect(throws: RequestSendError.unreadableInheritedAuth) {
            try tree.effectiveAuth(of: .request(request.id))
        }
    }

    @Test("Unreadable inherited auth reads in plain English")
    func unreadableDescription() {
        #expect(
            RequestSendError.unreadableInheritedAuth.errorDescription == "The auth this request inherits can’t be read."
        )
    }

    @Test("The context holds the stored request")
    func storedRequest() throws {
        let (dataModel, tree) = try tree()

        let context = try dataModel.sendContext(for: request.id, in: tree, environment: nil)

        #expect(context.request.urlTemplate == "https://example.com")
    }

    @Test("The data model names the workspace it shows, whose cookie jar a send uses")
    func namesTheWorkspace() throws {
        let (dataModel, _) = try tree()
        let workspace = try #require(dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>()).first)

        #expect(dataModel.workspaceID == workspace.id)
    }

    @Test("A store with no workspace has none to name")
    func noWorkspace() throws {
        #expect(try DataModel.inMemory().workspaceID == nil)
    }

    @Test("A request with no row refuses, because nothing can be sent")
    func missingRow() throws {
        let (dataModel, tree) = try tree()

        #expect(throws: RequestSendError.requestNotFound) {
            try dataModel.sendContext(for: UUID(), in: tree, environment: nil)
        }
    }

    @Test("A request that has gone reads in plain English")
    func missingRowDescription() {
        #expect(RequestSendError.requestNotFound.errorDescription == "This request no longer exists.")
    }

    @Test("Each scope comes from its own rows, in order")
    func scopes() throws {
        let request = Request(name: "List")
        let collection = RequestCollection(
            name: "API",
            variables: [.plain("collection", "1")],
            children: [TreeFixtures.item(0, request)]
        )
        let chosen = WorkspaceEnvironment(name: "Chosen", variables: [.plain("first", "1"), .plain("second", "2")])
        let other = WorkspaceEnvironment(name: "Other", variables: [.plain("other", "1")])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            collections: [collection],
            environments: [chosen, other],
            globals: [.plain("global", "1")]
        ))
        let tree = try CollectionTree(savedIn: dataModel)

        let context = try dataModel.sendContext(for: request.id, in: tree, environment: chosen.id)

        #expect(context.scopes.collection.map(\.name) == ["collection"])
        #expect(context.scopes.environment.map(\.name) == ["first", "second"])
        #expect(context.scopes.globals.map(\.name) == ["global"])
    }

    @Test("No active environment leaves that scope empty")
    func noEnvironment() throws {
        let (dataModel, tree) = try tree()

        let context = try dataModel.sendContext(for: request.id, in: tree, environment: nil)

        #expect(context.scopes.environment.isEmpty)
    }

    @Test("A variable changed by the writer is read fresh")
    func freshVariables() async throws {
        let environment = WorkspaceEnvironment(name: "Chosen", variables: [.plain("host", "old")])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            collections: [RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])],
            environments: [environment]
        ))
        let tree = try CollectionTree(savedIn: dataModel)
        let context = try dataModel.sendContext(for: request.id, in: tree, environment: environment.id)
        let variable = try #require(context.scopes.environment.first)
        var changed = variable
        changed.value = .plain(initial: "new", current: "new")

        try await dataModel.writer.updateVariable(changed, replacing: nil)

        let fresh = try dataModel.sendContext(for: request.id, in: tree, environment: environment.id)
        #expect(fresh.scopes.environment.first?.currentValue == "new")
    }

}
