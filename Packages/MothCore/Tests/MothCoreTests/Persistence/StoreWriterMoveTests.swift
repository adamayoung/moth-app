//  StoreWriterMoveTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterMoveTests {

    @Test("Reordering moves an item among its siblings, across both kinds")
    func reorderWithinAParent() async throws {
        let first = Request(name: "First")
        let second = Folder(name: "Second")
        let third = Request(name: "Third")
        let collection = RequestCollection(name: "API", children: [
            TreeFixtures.item(0, first),
            TreeFixtures.item(1, second),
            TreeFixtures.item(2, third)
        ])
        let container = TreeContainerID.collection(collection.id)
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.request(third.id), to: container, before: .request(first.id))
        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Third", "First", "Second"])

        try await dataModel.writer.moveItem(.folder(second.id), to: container, before: .request(first.id))
        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Third", "Second", "First"])

        try await dataModel.writer.moveItem(.request(third.id), to: container, before: nil)
        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Second", "First", "Third"])
    }

    @Test("Dropping an item before itself changes nothing")
    func moveBeforeItselfChangesNothing() async throws {
        let first = Request(name: "First")
        let second = Request(name: "Second")
        let collection = RequestCollection(
            name: "API",
            children: [TreeFixtures.item(0, first), TreeFixtures.item(1, second)]
        )
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.moveItem(
            .request(first.id),
            to: .collection(collection.id),
            before: .request(first.id)
        )

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["First", "Second"])
    }

    @Test("A request moved into a folder leaves its collection, and lands where it was dropped")
    func moveIntoAFolder() async throws {
        let request = Request(name: "Moved")
        let inside = Request(name: "Inside")
        let folder = Folder(name: "Folder", children: [TreeFixtures.item(0, inside)])
        let collection = RequestCollection(
            name: "API",
            children: [TreeFixtures.item(0, request), TreeFixtures.item(1, folder)]
        )
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.moveItem(
            .request(request.id),
            to: .folder(folder.id),
            before: .request(inside.id)
        )

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Folder"])
        #expect(try TreeFixtures.names(of: .folder(folder.id), in: dataModel) == ["Moved", "Inside"])
        let row = try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first { $0.id == request.id })
        #expect(row.collection == nil)
        #expect(row.folder?.id == folder.id)
    }

    @Test("A request moved out of a folder leaves the folder")
    func moveOutOfAFolder() async throws {
        let request = Request(name: "Moved")
        let folder = Folder(name: "Folder", children: [TreeFixtures.item(0, request)])
        let collection = RequestCollection(name: "API", children: [TreeFixtures.item(0, folder)])
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.request(request.id), to: .collection(collection.id), before: nil)

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Folder", "Moved"])
        #expect(try TreeFixtures.names(of: .folder(folder.id), in: dataModel).isEmpty)
        let row = try #require(TreeFixtures.savedRows(RequestModel.self, in: dataModel).first)
        #expect(row.folder == nil)
        #expect(row.collection?.id == collection.id)
    }

    @Test("A folder moved to another collection brings everything beneath it, and leaves the first")
    func moveAFolderBetweenCollections() async throws {
        let folder = Folder(name: "Moved", children: [TreeFixtures.item(0, Request(name: "Inside"))])
        let source = RequestCollection(name: "Source", children: [TreeFixtures.item(0, folder)])
        let target = RequestCollection(name: "Target", children: [TreeFixtures.item(0, Request(name: "There"))])
        let dataModel = try TreeFixtures.dataModel(holding: source, target)

        try await dataModel.writer.moveItem(.folder(folder.id), to: .collection(target.id), before: nil)

        #expect(try TreeFixtures.names(of: .collection(source.id), in: dataModel).isEmpty)
        #expect(try TreeFixtures.names(of: .collection(target.id), in: dataModel) == ["There", "Moved"])
        #expect(try TreeFixtures.names(of: .folder(folder.id), in: dataModel) == ["Inside"])
    }

    @Test("A folder moved into another folder leaves its collection, and one moved back leaves the folder")
    func moveAFolderInAndOutOfAFolder() async throws {
        let moved = Folder(name: "Moved")
        let target = Folder(name: "Target")
        let collection = RequestCollection(
            name: "API",
            children: [TreeFixtures.item(0, moved), TreeFixtures.item(1, target)]
        )
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.folder(moved.id), to: .folder(target.id), before: nil)
        let nested = try #require(TreeFixtures.savedRows(FolderModel.self, in: dataModel).first { $0.id == moved.id })
        #expect(nested.collection == nil)
        #expect(nested.parent?.id == target.id)

        try await dataModel.writer.moveItem(.folder(moved.id), to: .collection(collection.id), before: nil)
        let restored = try #require(TreeFixtures.savedRows(FolderModel.self, in: dataModel).first { $0.id == moved.id })
        #expect(restored.parent == nil)
        #expect(restored.collection?.id == collection.id)
    }

    @Test("A folder cannot move into itself or anything beneath it, and the tree stays as it was")
    func moveIntoItselfIsRefused() async throws {
        let inner = Folder(name: "Inner")
        let outer = Folder(name: "Outer", children: [TreeFixtures.item(0, inner)])
        let collection = RequestCollection(name: "API", children: [TreeFixtures.item(0, outer)])
        let dataModel = try TreeFixtures.dataModel(holding: collection)
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
        let dataModel = try TreeFixtures.dataModel(holding: moved, target)

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

    @Test("Moving a row that has gone leaves its would-be siblings' positions alone")
    func moveOfAMissingRowChangesNothing() async throws {
        let first = Request(name: "First")
        let second = Request(name: "Second")
        let third = Request(name: "Third")
        let collection = RequestCollection(name: "API", children: [
            TreeFixtures.item(0, first),
            TreeFixtures.item(2, second),
            TreeFixtures.item(5, third)
        ])
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.moveItem(.request(UUID()), to: .collection(collection.id), before: nil)

        let positions = try TreeFixtures.savedRows(RequestModel.self, in: dataModel).map(\.sortOrder).sorted()
        #expect(positions == [0, 2, 5])
    }

    @Test("Moving a collection that has gone leaves the others' positions alone")
    func moveOfAMissingCollectionChangesNothing() async throws {
        let dataModel = try DataModel.inMemory()
        for name in ["First", "Second", "Third"] {
            try await dataModel.writer.createCollection(RequestCollection(name: name))
        }
        try await dataModel.writer.delete(.collection(
            #require(CollectionTree(savedIn: dataModel).roots.first.flatMap { root -> UUID? in
                if case .collection(let id) = root.id {
                    return id
                }
                return nil
            })
        ))

        try await dataModel.writer.moveCollection(UUID(), before: nil)

        let positions = try TreeFixtures.savedRows(CollectionModel.self, in: dataModel).map(\.sortOrder).sorted()
        #expect(positions == [1, 2])
    }

    @Test("A duplicated folder acts as the row the tree shows, not whichever the fetch returns first")
    func twinContainerIsTheFirstInOrder() async throws {
        let folder = Folder(name: "Twin")
        let child = Folder(name: "Child")
        let shown = Folder(id: folder.id, name: "Twin", children: [TreeFixtures.item(0, child)])
        let collection = RequestCollection(name: "API", children: [TreeFixtures.item(5, shown)])
        let dataModel = try TreeFixtures.dataModel(holding: collection)
        let context = ModelContext(dataModel.container)
        let insertedFirst = try #require(context.fetch(FolderModel.withID(folder.id)).first)
        let childRow = try #require(context.fetch(FolderModel.withID(child.id)).first)
        let parent = try #require(context.fetch(CollectionModel.withID(collection.id)).first)
        let insertedLater = try FolderModel(Folder(id: folder.id, name: "Twin"), sortOrder: 0)
        context.insert(insertedLater)
        insertedLater.place(in: .collection(parent))
        insertedFirst.place(in: .folder(childRow))
        try context.save()

        try await dataModel.writer.moveItem(.folder(child.id), to: .folder(folder.id), before: nil)

        #expect(try TreeFixtures.names(of: .folder(folder.id), in: dataModel) == ["Child"])
    }

}
