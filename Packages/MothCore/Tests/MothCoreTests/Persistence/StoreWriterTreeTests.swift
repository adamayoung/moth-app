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

}
