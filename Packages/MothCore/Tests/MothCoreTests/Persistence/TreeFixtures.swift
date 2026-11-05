//  TreeFixtures.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

enum TreeFixtures {

    static func item(_ sortOrder: Int, _ folder: Folder) -> CollectionItem {
        CollectionItem(sortOrder: sortOrder, node: .folder(folder))
    }

    static func item(_ sortOrder: Int, _ request: Request) -> CollectionItem {
        CollectionItem(sortOrder: sortOrder, node: .request(request))
    }

    static func dataModel(holding collections: RequestCollection...) throws -> DataModel {
        try DataModel.inMemory(seed: Workspace(collections: collections))
    }

    /// A fresh context, because the rows under test were saved by another one.
    static func savedRows<Row: PersistentModel>(
        _ type: Row.Type,
        in dataModel: DataModel
    ) throws -> [Row] {
        try ModelContext(dataModel.container).fetch(FetchDescriptor<Row>())
    }

    static func names(of container: TreeNodeID, in dataModel: DataModel) throws -> [String] {
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

}
