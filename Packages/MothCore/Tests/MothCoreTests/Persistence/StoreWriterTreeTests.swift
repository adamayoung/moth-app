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

    @Test("Reordering moves an item among its siblings, across both kinds")
    func reorderWithinAParent() async throws {
        let first = Request(name: "First")
        let second = Folder(name: "Second")
        let third = Request(name: "Third")
        let collection = RequestCollection(name: "API", children: [
            Self.item(0, first),
            Self.item(1, second),
            Self.item(2, third)
        ])
        let container = TreeContainerID.collection(collection.id)
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.request(third.id), to: container, before: .request(first.id))
        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Third", "First", "Second"])

        try await dataModel.writer.moveItem(.folder(second.id), to: container, before: .request(first.id))
        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Third", "Second", "First"])

        try await dataModel.writer.moveItem(.request(third.id), to: container, before: nil)
        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Second", "First", "Third"])
    }

    @Test("Dropping an item before itself changes nothing")
    func moveBeforeItselfChangesNothing() async throws {
        let first = Request(name: "First")
        let second = Request(name: "Second")
        let collection = RequestCollection(name: "API", children: [Self.item(0, first), Self.item(1, second)])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.moveItem(
            .request(first.id),
            to: .collection(collection.id),
            before: .request(first.id)
        )

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["First", "Second"])
    }

    @Test("A request moved into a folder leaves its collection, and lands where it was dropped")
    func moveIntoAFolder() async throws {
        let request = Request(name: "Moved")
        let inside = Request(name: "Inside")
        let folder = Folder(name: "Folder", children: [Self.item(0, inside)])
        let collection = RequestCollection(name: "API", children: [Self.item(0, request), Self.item(1, folder)])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.moveItem(
            .request(request.id),
            to: .folder(folder.id),
            before: .request(inside.id)
        )

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Folder"])
        #expect(try Self.names(of: .folder(folder.id), in: dataModel) == ["Moved", "Inside"])
        let row = try #require(Self.savedRows(RequestModel.self, in: dataModel).first { $0.id == request.id })
        #expect(row.collection == nil)
        #expect(row.folder?.id == folder.id)
    }

    @Test("A request moved out of a folder leaves the folder")
    func moveOutOfAFolder() async throws {
        let request = Request(name: "Moved")
        let folder = Folder(name: "Folder", children: [Self.item(0, request)])
        let collection = RequestCollection(name: "API", children: [Self.item(0, folder)])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.request(request.id), to: .collection(collection.id), before: nil)

        #expect(try Self.names(of: .collection(collection.id), in: dataModel) == ["Folder", "Moved"])
        #expect(try Self.names(of: .folder(folder.id), in: dataModel).isEmpty)
        let row = try #require(Self.savedRows(RequestModel.self, in: dataModel).first)
        #expect(row.folder == nil)
        #expect(row.collection?.id == collection.id)
    }

    @Test("A folder moved to another collection brings everything beneath it, and leaves the first")
    func moveAFolderBetweenCollections() async throws {
        let folder = Folder(name: "Moved", children: [Self.item(0, Request(name: "Inside"))])
        let source = RequestCollection(name: "Source", children: [Self.item(0, folder)])
        let target = RequestCollection(name: "Target", children: [Self.item(0, Request(name: "There"))])
        let dataModel = try Self.dataModel(holding: source, target)

        try await dataModel.writer.moveItem(.folder(folder.id), to: .collection(target.id), before: nil)

        #expect(try Self.names(of: .collection(source.id), in: dataModel).isEmpty)
        #expect(try Self.names(of: .collection(target.id), in: dataModel) == ["There", "Moved"])
        #expect(try Self.names(of: .folder(folder.id), in: dataModel) == ["Inside"])
    }

    @Test("A folder moved into another folder leaves its collection, and one moved back leaves the folder")
    func moveAFolderInAndOutOfAFolder() async throws {
        let moved = Folder(name: "Moved")
        let target = Folder(name: "Target")
        let collection = RequestCollection(name: "API", children: [Self.item(0, moved), Self.item(1, target)])
        let dataModel = try Self.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.folder(moved.id), to: .folder(target.id), before: nil)
        let nested = try #require(Self.savedRows(FolderModel.self, in: dataModel).first { $0.id == moved.id })
        #expect(nested.collection == nil)
        #expect(nested.parent?.id == target.id)

        try await dataModel.writer.moveItem(.folder(moved.id), to: .collection(collection.id), before: nil)
        let restored = try #require(Self.savedRows(FolderModel.self, in: dataModel).first { $0.id == moved.id })
        #expect(restored.parent == nil)
        #expect(restored.collection?.id == collection.id)
    }

    @Test("A folder cannot move into itself or anything beneath it, and the tree stays as it was")
    func moveIntoItselfIsRefused() async throws {
        let inner = Folder(name: "Inner")
        let outer = Folder(name: "Outer", children: [Self.item(0, inner)])
        let collection = RequestCollection(name: "API", children: [Self.item(0, outer)])
        let dataModel = try Self.dataModel(holding: collection)
        let before = try CollectionTree(savedIn: dataModel)

        await #expect(throws: TreeWriteError.folderIntoItself) {
            try await dataModel.writer.moveItem(.folder(outer.id), to: .folder(outer.id), before: nil)
        }
        await #expect(throws: TreeWriteError.folderIntoItself) {
            try await dataModel.writer.moveItem(.folder(outer.id), to: .folder(inner.id), before: nil)
        }

        #expect(try CollectionTree(savedIn: dataModel) == before)
    }

    @Test("A collection cannot move into a folder or another collection")
    func moveItemRefusesACollection() async throws {
        let moved = RequestCollection(name: "Moved")
        let target = RequestCollection(name: "Target")
        let dataModel = try Self.dataModel(holding: moved, target)

        await #expect(throws: TreeWriteError.notMovable(.collection(moved.id))) {
            try await dataModel.writer.moveItem(.collection(moved.id), to: .collection(target.id), before: nil)
        }
    }

    @Test("Collections reorder before another collection and to the end")
    func reorderCollections() async throws {
        let first = RequestCollection(name: "First")
        let second = RequestCollection(name: "Second")
        let third = RequestCollection(name: "Third")
        let dataModel = try DataModel.inMemory()
        for collection in [first, second, third] {
            try await dataModel.writer.createCollection(collection)
        }

        try await dataModel.writer.moveCollection(third.id, before: first.id)
        #expect(try CollectionTree(savedIn: dataModel).roots.map(\.name) == ["Third", "First", "Second"])

        try await dataModel.writer.moveCollection(third.id, before: nil)
        #expect(try CollectionTree(savedIn: dataModel).roots.map(\.name) == ["First", "Second", "Third"])
    }

    @Test("A create, rename, move and delete survive a new container on the same store")
    func changesSurviveANewContainer() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "StoreWriterTreeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collection = RequestCollection(name: "Before")
        let folder = Folder(name: "Folder")
        let moved = Request(name: "Moved")
        let deleted = Request(name: "Deleted")

        do {
            let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
            try await dataModel.writer.createCollection(collection)
            try await dataModel.writer.rename(.collection(collection.id), to: "After")
            try await dataModel.writer.createFolder(folder, in: .collection(collection.id))
            try await dataModel.writer.createRequest(moved, in: .collection(collection.id))
            try await dataModel.writer.createRequest(deleted, in: .collection(collection.id))
            try await dataModel.writer.moveItem(.request(moved.id), to: .folder(folder.id), before: nil)
            try await dataModel.writer.delete(.request(deleted.id))
        }

        let reopened = try DataModel(location: .directory(directory), containerIdentifier: nil)
        let tree = try CollectionTree(savedIn: reopened)
        #expect(tree.roots.map(\.name) == ["After"])
        #expect(try Self.names(of: .collection(collection.id), in: reopened) == ["Folder"])
        #expect(try Self.names(of: .folder(folder.id), in: reopened) == ["Moved"])
    }

}
