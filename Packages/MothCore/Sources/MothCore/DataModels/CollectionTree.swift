//  CollectionTree.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum TreeNodeID: Hashable, Sendable, Codable {

    case collection(UUID)
    case folder(UUID)
    case request(UUID)

}

public nonisolated enum TreeContainerID: Hashable, Sendable {

    case collection(UUID)
    case folder(UUID)

}

public nonisolated struct TreeNode: Identifiable, Hashable, Sendable {

    public let id: TreeNodeID
    public let name: String
    public let method: HTTPMethod?
    public let children: [TreeNode]

    public var requestCount: Int {
        children.reduce(method == nil ? 0 : 1) { $0 + $1.requestCount }
    }

}

public nonisolated struct CollectionTree: Hashable, Sendable {

    public let roots: [TreeNode]

    /// Takes flat rows, not a collection's arrays: a to-many array held by the main context goes stale once the writer
    /// saves, while a fetch brings each row's parent up to date. Walking down from the collections leaves an orphan, or
    /// a folder cycle two Macs made between them, out of the tree.
    public init(collections: [CollectionModel], folders: [FolderModel], requests: [RequestModel]) {
        let index = ChildIndex(folders: folders, requests: requests)
        self.roots = collections.inSortOrder.map { row in
            TreeNode(
                id: .collection(row.id),
                name: row.name,
                method: nil,
                children: index.children(of: .collection(row.id))
            )
        }
    }

}

private nonisolated struct ChildIndex {

    private let folders: [TreeContainerID: [FolderModel]]
    private let requests: [TreeContainerID: [RequestModel]]

    init(folders: [FolderModel], requests: [RequestModel]) {
        self.folders = Self.grouped(folders, by: \.container)
        self.requests = Self.grouped(requests, by: \.container)
    }

    /// A folder and a request share one ordering, so their `sortOrder` values interleave.
    func children(of container: TreeContainerID) -> [TreeNode] {
        let folderRows = (folders[container] ?? []).map { row in
            (row.sortOrder, row.id, node(for: row))
        }
        let requestRows = (requests[container] ?? []).map { row in
            (row.sortOrder, row.id, node(for: row))
        }
        return (folderRows + requestRows)
            .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
            .map(\.2)
    }

    private static func grouped<Row>(
        _ rows: [Row],
        by container: (Row) -> TreeContainerID?
    ) -> [TreeContainerID: [Row]] {
        rows.reduce(into: [:]) { groups, row in
            if let container = container(row) {
                groups[container, default: []].append(row)
            }
        }
    }

    private func node(for row: FolderModel) -> TreeNode {
        TreeNode(
            id: .folder(row.id),
            name: row.name,
            method: nil,
            children: children(of: .folder(row.id))
        )
    }

    private func node(for row: RequestModel) -> TreeNode {
        TreeNode(
            id: .request(row.id),
            name: row.name,
            method: HTTPMethod(rawValue: row.methodRawValue),
            children: []
        )
    }

}

private nonisolated extension FolderModel {

    var container: TreeContainerID? {
        parent.map { .folder($0.id) } ?? collection.map { .collection($0.id) }
    }

}

private nonisolated extension RequestModel {

    var container: TreeContainerID? {
        folder.map { .folder($0.id) } ?? collection.map { .collection($0.id) }
    }

}
