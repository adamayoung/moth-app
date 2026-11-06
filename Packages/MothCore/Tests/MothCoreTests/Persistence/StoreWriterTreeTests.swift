//  StoreWriterTreeTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterTreeTests {

    @Test("A new folder goes after the last child of either kind, in a collection and in a folder")
    func newFolderGoesLast() async throws {
        let folder = Folder(name: "Folder", children: [TreeFixtures.item(5, Request(name: "Inside"))])
        let collection = RequestCollection(name: "API", children: [
            TreeFixtures.item(0, folder),
            TreeFixtures.item(1, Request(name: "Beside"))
        ])
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.createFolder(Folder(name: "New"), in: .collection(collection.id))
        try await dataModel.writer.createFolder(Folder(name: "Nested"), in: .folder(folder.id))

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Folder", "Beside", "New"])
        #expect(try TreeFixtures.names(of: .folder(folder.id), in: dataModel) == ["Inside", "Nested"])
    }

    @Test("A new request goes after the last child of either kind, in a collection and in a folder")
    func newRequestGoesLast() async throws {
        let folder = Folder(name: "Folder", children: [TreeFixtures.item(5, Folder(name: "Inside"))])
        let collection = RequestCollection(name: "API", children: [
            TreeFixtures.item(0, Request(name: "Beside")),
            TreeFixtures.item(1, folder)
        ])
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.createRequest(Request(name: "New"), in: .collection(collection.id))
        try await dataModel.writer.createRequest(Request(name: "Nested"), in: .folder(folder.id))

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Beside", "Folder", "New"])
        #expect(try TreeFixtures.names(of: .folder(folder.id), in: dataModel) == ["Inside", "Nested"])
    }

    @Test("Renaming changes the name of a collection, a folder and a request")
    func renameEachKind() async throws {
        let folder = Folder(name: "Folder")
        let request = Request(name: "Request")
        let collection = RequestCollection(
            name: "API",
            children: [TreeFixtures.item(0, folder), TreeFixtures.item(1, request)]
        )
        let dataModel = try TreeFixtures.dataModel(holding: collection)

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
        let collection = RequestCollection(
            name: "API",
            children: [TreeFixtures.item(0, request), TreeFixtures.item(1, kept)]
        )
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.delete(.request(request.id))

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Kept"])
        #expect(try TreeFixtures.savedRows(VariableModel.self, in: dataModel).isEmpty)
    }

    @Test("Deleting a folder removes everything beneath it and leaves its siblings")
    func deleteFolderCascades() async throws {
        let inner = Folder(name: "Inner", children: [
            TreeFixtures.item(0, Request(name: "Deep", variables: [DomainFixtures.variable(named: "deep")]))
        ])
        let folder = Folder(
            name: "Gone",
            children: [TreeFixtures.item(0, inner), TreeFixtures.item(1, Request(name: "Shallow"))]
        )
        let collection = RequestCollection(name: "API", children: [
            TreeFixtures.item(0, folder),
            TreeFixtures.item(1, Request(name: "Kept"))
        ])
        let dataModel = try TreeFixtures.dataModel(holding: collection)

        try await dataModel.writer.delete(.folder(folder.id))

        #expect(try TreeFixtures.names(of: .collection(collection.id), in: dataModel) == ["Kept"])
        #expect(try TreeFixtures.savedRows(FolderModel.self, in: dataModel).isEmpty)
        #expect(try TreeFixtures.savedRows(RequestModel.self, in: dataModel).map(\.name) == ["Kept"])
        #expect(try TreeFixtures.savedRows(VariableModel.self, in: dataModel).isEmpty)
    }

    @Test("Deleting a collection removes everything beneath it, leaves the others and keeps the workspace")
    func deleteCollectionCascades() async throws {
        let gone = RequestCollection(
            name: "Gone",
            variables: [DomainFixtures.variable(named: "gone")],
            children: [TreeFixtures.item(
                0,
                Folder(name: "Folder", children: [TreeFixtures.item(0, Request(name: "Deep"))])
            )]
        )
        let kept = RequestCollection(name: "Kept", children: [TreeFixtures.item(0, Request(name: "Kept"))])
        let dataModel = try TreeFixtures.dataModel(holding: gone, kept)

        try await dataModel.writer.delete(.collection(gone.id))

        #expect(try CollectionTree(savedIn: dataModel).roots.map(\.name) == ["Kept"])
        #expect(try TreeFixtures.savedRows(FolderModel.self, in: dataModel).isEmpty)
        #expect(try TreeFixtures.savedRows(RequestModel.self, in: dataModel).map(\.name) == ["Kept"])
        #expect(try TreeFixtures.savedRows(VariableModel.self, in: dataModel).isEmpty)
        #expect(try TreeFixtures.savedRows(WorkspaceModel.self, in: dataModel).count == 1)
    }

    @Test("A row sync duplicated is renamed and deleted along with its twin")
    func duplicatedRowsChangeTogether() async throws {
        let request = Request(name: "Twin")
        let collection = RequestCollection(name: "API", children: [TreeFixtures.item(0, request)])
        let dataModel = try TreeFixtures.dataModel(holding: collection)
        let context = ModelContext(dataModel.container)
        let parent = try #require(context.fetch(CollectionModel.withID(collection.id)).first)
        let twin = try RequestModel(request, sortOrder: 1)
        context.insert(twin)
        twin.place(in: .collection(parent))
        try context.save()

        try await dataModel.writer.rename(.request(request.id), to: "Renamed")
        let renamed = try TreeFixtures.savedRows(RequestModel.self, in: dataModel).map(\.name)
        try await dataModel.writer.delete(.request(request.id))

        #expect(renamed == ["Renamed", "Renamed"])
        #expect(try TreeFixtures.savedRows(RequestModel.self, in: dataModel).isEmpty)
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
        #expect(try TreeFixtures.names(of: .collection(collection.id), in: reopened) == ["Folder"])
        #expect(try TreeFixtures.names(of: .folder(folder.id), in: reopened) == ["Moved"])
    }

    @Test("A delete reaches a child saved by another context after the writer last read the parent")
    func deleteReachesAChildAddedElsewhere() async throws {
        let folder = Folder(name: "Folder")
        let collection = RequestCollection(name: "API", children: [TreeFixtures.item(0, folder)])
        let dataModel = try TreeFixtures.dataModel(holding: collection)
        try await dataModel.writer.createRequest(Request(name: "Known"), in: .folder(folder.id))
        let context = ModelContext(dataModel.container)
        let parent = try #require(context.fetch(FolderModel.withID(folder.id)).first)
        let imported = try RequestModel(
            Request(name: "Imported", variables: [DomainFixtures.variable(named: "imported")]),
            sortOrder: 1
        )
        context.insert(imported)
        imported.place(in: .folder(parent))
        try context.save()

        try await dataModel.writer.delete(.folder(folder.id))

        #expect(try TreeFixtures.savedRows(RequestModel.self, in: dataModel).isEmpty)
        #expect(try TreeFixtures.savedRows(VariableModel.self, in: dataModel).isEmpty)
    }

}
