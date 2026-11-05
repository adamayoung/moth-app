//  SidebarMove.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore

/// Which list a row sits in. Top-level collections have no container, so `TreeContainerID` alone cannot name theirs.
nonisolated enum SidebarParent: Hashable, Sendable {

    case root
    case container(TreeContainerID)

}

enum SidebarMove: Equatable {

    case collection(UUID, before: UUID?)
    case item(TreeNodeID, into: TreeContainerID, before: TreeNodeID?)

    /// Nil for a drop the tree cannot hold, which leaves the row where it was.
    init?(moving id: TreeNodeID, to parent: SidebarParent, before: TreeNodeID?, in tree: CollectionTree) {
        switch (id, parent) {
        case (.collection(let id), .root):
            self = .collection(id, before: before.flatMap(Self.collectionID))
        case (.collection, .container), (_, .root):
            return nil
        case (_, .container(let container)):
            let destination = TreeNodeID(container)
            guard destination != id, !tree.ancestors(of: destination).contains(id) else {
                return nil
            }
            self = .item(id, into: container, before: before)
        }
    }

    private static func collectionID(_ id: TreeNodeID) -> UUID? {
        guard case .collection(let id) = id else {
            return nil
        }
        return id
    }

}
