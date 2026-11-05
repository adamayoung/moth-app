//  CollectionItem.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct CollectionItem: Identifiable, Sendable, Hashable {

    public var sortOrder: Int
    public var node: CollectionNode

    public var id: UUID {
        switch node {
        case .folder(let folder): folder.id
        case .request(let request): request.id
        }
    }

    public init(sortOrder: Int, node: CollectionNode) {
        self.sortOrder = sortOrder
        self.node = node
    }

    /// Ties fall back to `id` because a sync can give two children one `sortOrder`, and devices must agree.
    /// Sorted only when a whole array is set: sorting on each element write would move an index mid-edit.
    static func inOrder(_ items: [CollectionItem]) -> [CollectionItem] {
        items.sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
    }

}

public nonisolated enum CollectionNode: Sendable, Hashable {

    case folder(Folder)
    case request(Request)

}
