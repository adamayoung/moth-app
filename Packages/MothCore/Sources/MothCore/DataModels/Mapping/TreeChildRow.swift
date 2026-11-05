//  TreeChildRow.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import SwiftData

nonisolated enum TreeContainerRow {

    case collection(CollectionModel)
    case folder(FolderModel)

}

nonisolated protocol NamedTreeRow: PersistentModel {

    var name: String { get set }

}

nonisolated extension CollectionModel: NamedTreeRow {}
nonisolated extension FolderModel: NamedTreeRow {}
nonisolated extension RequestModel: NamedTreeRow {}

nonisolated protocol OrderedTreeRow: PersistentModel, SortedRow {

    var sortOrder: Int { get set }

}

nonisolated extension CollectionModel: OrderedTreeRow {}

/// A folder or request under a collection or folder. The two kinds share one `sortOrder` sequence within a parent.
nonisolated protocol TreeChildRow: OrderedTreeRow {

    var container: TreeContainerID? { get }

    func place(in container: TreeContainerRow)

}

nonisolated extension FolderModel: SortedRow {}
nonisolated extension RequestModel: SortedRow {}

nonisolated extension FolderModel: TreeChildRow {

    var container: TreeContainerID? {
        parent.map { .folder($0.id) } ?? collection.map { .collection($0.id) }
    }

    /// Compares first because an equal-value assignment still rewrites the row.
    func place(in container: TreeContainerRow) {
        switch container {
        case .collection(let row):
            if parent != nil {
                parent = nil
            }
            if collection?.persistentModelID != row.persistentModelID {
                collection = row
            }
        case .folder(let row):
            if collection != nil {
                collection = nil
            }
            if parent?.persistentModelID != row.persistentModelID {
                parent = row
            }
        }
    }

}

nonisolated extension RequestModel: TreeChildRow {

    var container: TreeContainerID? {
        folder.map { .folder($0.id) } ?? collection.map { .collection($0.id) }
    }

    /// Compares first because an equal-value assignment still rewrites the row.
    func place(in container: TreeContainerRow) {
        switch container {
        case .collection(let row):
            if folder != nil {
                folder = nil
            }
            if collection?.persistentModelID != row.persistentModelID {
                collection = row
            }
        case .folder(let row):
            if collection != nil {
                collection = nil
            }
            if folder?.persistentModelID != row.persistentModelID {
                folder = row
            }
        }
    }

}
