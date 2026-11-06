//  CollectionTree.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated enum TreeNodeID: Hashable, Sendable, Codable {

    case collection(UUID)
    case folder(UUID)
    case request(UUID)

    public init(_ container: TreeContainerID) {
        switch container {
        case .collection(let id): self = .collection(id)
        case .folder(let id): self = .folder(id)
        }
    }

    var uuid: UUID {
        switch self {
        case .collection(let id), .folder(let id), .request(let id): id
        }
    }

}

public nonisolated enum TreeContainerID: Hashable, Sendable {

    case collection(UUID)
    case folder(UUID)

    /// Nil for a request, which holds nothing.
    public init?(_ node: TreeNodeID) {
        switch node {
        case .collection(let id): self = .collection(id)
        case .folder(let id): self = .folder(id)
        case .request: return nil
        }
    }

}

/// Where an `.inherit` gets its auth, for the editor to say.
public nonisolated enum InheritedAuth: Hashable, Sendable {

    case from(String)
    case nothing

}

public nonisolated struct TreeNode: Identifiable, Hashable, Sendable {

    public let id: TreeNodeID
    public let name: String
    public let method: HTTPMethod?
    /// `nil` for a request, whose auth the tree leaves undecoded, and for a container whose stored auth can't be read.
    public let auth: Auth?
    public let children: [TreeNode]

    public var requestCount: Int {
        children.reduce(method == nil ? 0 : 1) { $0 + $1.requestCount }
    }

}

public nonisolated struct CollectionTree: Hashable, Sendable {

    public static let empty = CollectionTree(roots: [])

    public let roots: [TreeNode]

    init(roots: [TreeNode]) {
        self.roots = roots
    }

    /// Moves a selection only on its transition out of the tree, so a row made a moment ago keeps its selection until
    /// the query delivers it.
    public func selection(_ selection: TreeNodeID?, carriedTo newTree: CollectionTree) -> TreeNodeID? {
        guard let selection, contains(selection), !newTree.contains(selection) else {
            return selection
        }
        return ancestors(of: selection).last(where: newTree.contains)
    }

    /// From the collection down to the node's parent.
    public func ancestors(of id: TreeNodeID) -> [TreeNodeID] {
        Self.path(to: id, in: roots)?.dropLast().map(\.id) ?? []
    }

    /// Walks as `RequestCollection.effectiveAuth(of:)` does, so what this says is what sending will find. A container
    /// whose auth can't be read still ends the walk, because it holds something.
    public func inheritedAuth(of id: TreeNodeID) -> InheritedAuth {
        let ancestors = (Self.path(to: id, in: roots) ?? []).dropLast()
        guard let source = ancestors.last(where: { $0.auth != .inherit }), source.auth != Auth.none else {
            return .nothing
        }
        return .from(source.name)
    }

    public func node(_ id: TreeNodeID) -> TreeNode? {
        Self.path(to: id, in: roots)?.last
    }

    public func contains(_ id: TreeNodeID) -> Bool {
        node(id) != nil
    }

    private static func path(to id: TreeNodeID, in nodes: [TreeNode]) -> [TreeNode]? {
        for node in nodes {
            if node.id == id {
                return [node]
            }
            if let descendants = path(to: id, in: node.children) {
                return [node] + descendants
            }
        }
        return nil
    }

    /// Takes flat rows, not a collection's arrays: a to-many array held by the main context goes stale once the writer
    /// saves, while a fetch brings each row's parent up to date. Keeping one row per id gives each id one parent, so
    /// walking down from the collections leaves an orphan, or a folder cycle two Macs made, out of the tree.
    public init(collections: [CollectionModel], folders: [FolderModel], requests: [RequestModel]) {
        let index = ChildIndex(folders: folders, requests: requests)
        self.roots = collections.oneRowPerID.map { row in
            TreeNode(
                id: .collection(row.id),
                name: row.name,
                method: nil,
                auth: try? row.storedAuth,
                children: index.children(of: .collection(row.id))
            )
        }
    }

}

private nonisolated struct ChildIndex {

    private let folders: [TreeContainerID: [FolderModel]]
    private let requests: [TreeContainerID: [RequestModel]]

    init(folders: [FolderModel], requests: [RequestModel]) {
        self.folders = Self.grouped(folders.oneRowPerID, by: \.container)
        self.requests = Self.grouped(requests.oneRowPerID, by: \.container)
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
            auth: try? row.storedAuth,
            children: children(of: .folder(row.id))
        )
    }

    private func node(for row: RequestModel) -> TreeNode {
        TreeNode(
            id: .request(row.id),
            name: row.name,
            method: HTTPMethod(rawValue: row.methodRawValue),
            auth: nil,
            children: []
        )
    }

}
