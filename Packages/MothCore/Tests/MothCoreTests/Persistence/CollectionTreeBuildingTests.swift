//  CollectionTreeBuildingTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct CollectionTreeBuildingTests {

    @Test("Folders and requests interleave in sort order, and a request row carries its method")
    func childrenInterleaveInOrder() throws {
        let request = Request(name: "Create", method: .post)
        let folder = Folder(name: "Users")
        let later = Request(name: "List")
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 2, node: .request(later)),
            CollectionItem(sortOrder: 0, node: .request(request)),
            CollectionItem(sortOrder: 1, node: .folder(folder))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))

        let tree = try CollectionTree(savedIn: dataModel)

        let root = try #require(tree.roots.first)
        #expect(root.id == .collection(collection.id))
        #expect(root.children.map(\.id) == [.request(request.id), .folder(folder.id), .request(later.id)])
        #expect(root.children.map(\.name) == ["Create", "Users", "List"])
        #expect(root.children.map(\.method) == [.post, nil, .get])
    }

    @Test("A node counts the requests beneath it, through every subfolder")
    func requestCountIsRecursive() throws {
        let inner = Folder(name: "Inner", children: [
            CollectionItem(sortOrder: 0, node: .request(Request(name: "Deep")))
        ])
        let outer = Folder(name: "Outer", children: [
            CollectionItem(sortOrder: 0, node: .folder(inner)),
            CollectionItem(sortOrder: 1, node: .request(Request(name: "Shallow")))
        ])
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(outer)),
            CollectionItem(sortOrder: 1, node: .folder(Folder(name: "Empty"))),
            CollectionItem(sortOrder: 2, node: .request(Request(name: "Top")))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))

        let tree = try CollectionTree(savedIn: dataModel)

        let root = try #require(tree.roots.first)
        #expect(root.requestCount == 3)
        #expect(root.children.map(\.requestCount) == [2, 0, 1])
    }

    @Test("A folder or request whose parent has not synced stays out of the tree")
    func orphansAreHidden() throws {
        let collection = RequestCollection(name: "API")
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let context = ModelContext(dataModel.container)
        try context.insert(FolderModel(Folder(name: "Orphan"), sortOrder: 0))
        try context.insert(RequestModel(Request(name: "Orphan"), sortOrder: 0))
        try context.save()

        let tree = try CollectionTree(savedIn: dataModel)

        #expect(tree.roots.map(\.children) == [[]])
    }

    @Test("Two folders that became each other's parent stay out of the tree, rather than recursing forever")
    func folderCycleIsHidden() throws {
        let collection = RequestCollection(name: "API")
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let context = ModelContext(dataModel.container)
        let first = try FolderModel(Folder(name: "First"), sortOrder: 0)
        let second = try FolderModel(Folder(name: "Second"), sortOrder: 0)
        context.insert(first)
        context.insert(second)
        first.parent = second
        second.parent = first
        try context.save()

        let tree = try CollectionTree(savedIn: dataModel)

        #expect(tree.roots.map(\.children) == [[]])
    }

    @Test("A row sync duplicated appears once, and counts once")
    func duplicatedRowAppearsOnce() throws {
        let request = Request(name: "Twin")
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .request(request))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let context = ModelContext(dataModel.container)
        let parent = try #require(context.fetch(CollectionModel.withID(collection.id)).first)
        let twin = try RequestModel(request, sortOrder: 1)
        context.insert(twin)
        twin.place(in: .collection(parent))
        try context.save()

        let tree = try CollectionTree(savedIn: dataModel)

        let root = try #require(tree.roots.first)
        #expect(root.children.map(\.id) == [.request(request.id)])
        #expect(root.requestCount == 1)
    }

    @Test("A duplicated folder cannot lead the tree round a cycle")
    func duplicatedFolderCannotReachACycle() throws {
        let folder = Folder(name: "Twin")
        let collection = RequestCollection(name: "API", children: [
            CollectionItem(sortOrder: 0, node: .folder(folder))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let context = ModelContext(dataModel.container)
        let original = try #require(context.fetch(FolderModel.withID(folder.id)).first)
        let middle = try FolderModel(Folder(name: "Middle"), sortOrder: 0)
        let twin = try FolderModel(folder, sortOrder: 1)
        context.insert(middle)
        context.insert(twin)
        middle.place(in: .folder(original))
        twin.place(in: .folder(middle))
        try context.save()

        let tree = try CollectionTree(savedIn: dataModel)

        #expect(tree.contains(.folder(folder.id)))
    }

}
