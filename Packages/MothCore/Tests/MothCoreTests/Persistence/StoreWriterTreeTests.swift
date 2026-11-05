//  StoreWriterTreeTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterTreeTests {

    private static func item(_ sortOrder: Int, _ folder: Folder) -> CollectionItem {
        CollectionItem(sortOrder: sortOrder, node: .folder(folder))
    }

    private static func item(_ sortOrder: Int, _ request: Request) -> CollectionItem {
        CollectionItem(sortOrder: sortOrder, node: .request(request))
    }

    private static func dataModel(holding collections: RequestCollection...) throws -> DataModel {
        try DataModel.inMemory(seed: Workspace(collections: collections))
    }

    /// A fresh context, because the rows under test were saved by another one.
    private static func savedRows<Row: PersistentModel>(
        _ type: Row.Type,
        in dataModel: DataModel
    ) throws -> [Row] {
        try ModelContext(dataModel.container).fetch(FetchDescriptor<Row>())
    }

    private static func names(of container: TreeNodeID, in dataModel: DataModel) throws -> [String] {
        let tree = try CollectionTree(savedIn: dataModel)
        return try #require(node(container, in: tree.roots)).children.map(\.name)
    }

    private static func node(_ id: TreeNodeID, in nodes: [TreeNode]) -> TreeNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let match = self.node(id, in: node.children) {
                return match
            }
        }
        return nil
    }

    @Test("A new folder goes after the last child of either kind, in a collection and in a folder")
    func newFolderGoesLast() async throws {
        let folder = Folder(name: "Folder", children: [Self.item(5, Request(name: "Inside"))])
        let collection = RequestCollection(name: "API", children: [
            Self.item(0, folder),
            Self.item(1, Request(name: "Beside"))
        ])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.createFolder(Folder(name: "New"), in: .collection(collection.id))
        try await dataModel.writer.createFolder(Folder(name: "Nested"), in: .folder(folder.id))

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Folder", "Beside", "New"])
        #expect(try Self.names(of: .folder(folder.id), in: dataModel) == ["Inside", "Nested"])
    }

    @Test("A new request goes after the last child of either kind, in a collection and in a folder")
    func newRequestGoesLast() async throws {
        let folder = Folder(name: "Folder", children: [Self.item(5, Folder(name: "Inside"))])
        let collection = RequestCollection(name: "API", children: [
            Self.item(0, Request(name: "Beside")),
            Self.item(1, folder)
        ])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.createRequest(Request(name: "New"), in: .collection(collection.id))
        try await dataModel.writer.createRequest(Request(name: "Nested"), in: .folder(folder.id))

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Beside", "Folder", "New"])
        #expect(try Self.names(of: .folder(folder.id), in: dataModel) == ["Inside", "Nested"])
    }

    @Test("Renaming changes the name of a collection, a folder and a request")
    func renameEachKind() async throws {
        let folder = Folder(name: "Folder")
        let request = Request(name: "Request")
        let collection = RequestCollection(name: "API", children: [Self.item(0, folder), Self.item(1, request)])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.rename(.collection(collection.id), to: "Renamed Collection")
        try await dataModel.writer.rename(.folder(folder.id), to: "Renamed Folder")
        try await dataModel.writer.rename(.request(request.id), to: "Renamed Request")

        let tree = try CollectionTree(savedIn: dataModel)
        #expect(tree.roots.map(\.name) == ["Renamed Collection"])
        #expect(tree.roots.flatMap(\.children).map(\.name) == ["Renamed Folder", "Renamed Request"])
    }

    @Test("Deleting a request removes only that request and its variables")
    func deleteRequest() async throws {
        let request = Request(name: "Gone", variables: [DomainFixtures.variable(named: "gone")])
        let kept = Request(name: "Kept")
        let collection = RequestCollection(name: "API", children: [Self.item(0, request), Self.item(1, kept)])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.delete(.request(request.id))

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Kept"])
        #expect(try Self.savedRows(VariableModel.self, in: dataModel).isEmpty)
    }

    @Test("Deleting a folder removes everything beneath it and leaves its siblings")
    func deleteFolderCascades() async throws {
        let inner = Folder(name: "Inner", children: [
            Self.item(0, Request(name: "Deep", variables: [DomainFixtures.variable(named: "deep")]))
        ])
        let folder = Folder(name: "Gone", children: [Self.item(0, inner), Self.item(1, Request(name: "Shallow"))])
        let collection = RequestCollection(name: "API", children: [
            Self.item(0, folder),
            Self.item(1, Request(name: "Kept"))
        ])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.delete(.folder(folder.id))

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Kept"])
        #expect(try Self.savedRows(FolderModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(RequestModel.self, in: dataModel).map(\.name) == ["Kept"])
        #expect(try Self.savedRows(VariableModel.self, in: dataModel).isEmpty)
    }

    @Test("Deleting a collection removes everything beneath it, leaves the others and keeps the workspace")
    func deleteCollectionCascades() async throws {
        let gone = RequestCollection(
            name: "Gone",
            variables: [DomainFixtures.variable(named: "gone")],
            children: [Self.item(0, Folder(name: "Folder", children: [Self.item(0, Request(name: "Deep"))]))]
        )
        let kept = RequestCollection(name: "Kept", children: [Self.item(0, Request(name: "Kept"))])
        let dataModel = try Self.dataModel(holding: gone, kept)

        try await dataModel.writer.delete(.collection(gone.id))

        #expect(try CollectionTree(savedIn: dataModel).roots.map(\.name) == ["Kept"])
        #expect(try Self.savedRows(FolderModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(RequestModel.self, in: dataModel).map(\.name) == ["Kept"])
        #expect(try Self.savedRows(VariableModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(WorkspaceModel.self, in: dataModel).count == 1)
    }

    @Test("A row sync duplicated is renamed and deleted along with its twin")
    func duplicatedRowsChangeTogether() async throws {
        let request = Request(name: "Twin")
        let collection = RequestCollection(name: "API", children: [Self.item(0, request)])
        let dataModel = try Self.dataModel(holding: collection)
        let context = ModelContext(dataModel.container)
        let parent = try #require(context.fetch(CollectionModel.withID(collection.id)).first)
        let twin = try RequestModel(request, sortOrder: 1)
        context.insert(twin)
        twin.place(in: .collection(parent))
        try context.save()

        try await dataModel.writer.rename(.request(request.id), to: "Renamed")
        let renamed = try Self.savedRows(RequestModel.self, in: dataModel).map(\.name)
        try await dataModel.writer.delete(.request(request.id))

        #expect(renamed == ["Renamed", "Renamed"])
        #expect(try Self.savedRows(RequestModel.self, in: dataModel).isEmpty)
    }

}
