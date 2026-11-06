//  StoreWriter+Tree.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public nonisolated enum TreeWriteError: Error, Equatable {

    case containerNotFound(TreeContainerID)
    case folderIntoItself
    case notMovable(TreeNodeID)

}

extension StoreWriter {

    public func createFolder(_ folder: Folder, in container: TreeContainerID) throws {
        try write { context in
            let parent = try Self.containerRow(container, in: context)
            let row = try FolderModel(folder, sortOrder: Self.nextSortOrder(in: container, context: context))
            context.insert(row)
            row.place(in: parent)
        }
    }

    public func createRequest(_ request: Request, in container: TreeContainerID) throws {
        try write { context in
            let parent = try Self.containerRow(container, in: context)
            let row = try RequestModel(request, sortOrder: Self.nextSortOrder(in: container, context: context))
            context.insert(row)
            row.place(in: parent)
        }
    }

    public func rename(_ id: TreeNodeID, to name: String) throws {
        try write { context in
            for row in try Self.rows(id, in: context) where row.name != name {
                row.name = name
            }
        }
    }

    public func delete(_ id: TreeNodeID) throws {
        try write { context in
            for row in try Self.rows(id, in: context) {
                context.delete(row)
            }
        }
    }

    /// Moves a folder or request to sit ahead of `before` in `container`, or last if `before` is nil or has gone.
    public func moveItem(_ id: TreeNodeID, to container: TreeContainerID, before: TreeNodeID?) throws {
        guard id != before else {
            return
        }
        try write { context in
            let moved = try Self.childRows(id, in: context)
            guard !moved.isEmpty else {
                return
            }
            let parent = try Self.containerRow(container, in: context)
            try Self.refuseFolderIntoItself(id, parent: parent)
            let siblings = try Self.children(of: container, in: context)
            for row in moved {
                row.place(in: parent)
            }
            Self.order(siblings, moving: moved, before: before?.uuid)
        }
    }

    public func moveCollection(_ id: UUID, before: UUID?) throws {
        guard id != before else {
            return
        }
        try write { context in
            let collections = try context.fetch(FetchDescriptor<CollectionModel>()).inSortOrder
            let moved = collections.filter { $0.id == id }
            guard !moved.isEmpty else {
                return
            }
            Self.order(collections, moving: moved, before: before)
        }
    }

    private static func childRows(_ id: TreeNodeID, in context: ModelContext) throws -> [any TreeChildRow] {
        switch id {
        case .collection: throw TreeWriteError.notMovable(id)
        case .folder(let id): try context.fetch(FolderModel.withID(id))
        case .request(let id): try context.fetch(RequestModel.withID(id))
        }
    }

    /// Tracks visited folders because two Macs can each make half of a cycle, which would otherwise never end.
    private static func refuseFolderIntoItself(_ id: TreeNodeID, parent: TreeContainerRow) throws {
        guard case .folder(let movedID) = id, case .folder(let destination) = parent else {
            return
        }
        var visited: Set<UUID> = []
        var ancestor: FolderModel? = destination
        while let folder = ancestor, visited.insert(folder.id).inserted {
            if folder.id == movedID {
                throw TreeWriteError.folderIntoItself
            }
            ancestor = folder.parent
        }
    }

    /// Writes only the rows whose position changed, so a reorder syncs as few rows as it can.
    private static func order(
        _ siblings: [any OrderedTreeRow],
        moving moved: [any OrderedTreeRow],
        before: UUID?
    ) {
        let movedIDs = Set(moved.map(\.id))
        var ordered = siblings.filter { !movedIDs.contains($0.id) }
        let index = ordered.firstIndex { $0.id == before } ?? ordered.endIndex
        ordered.insert(contentsOf: moved, at: index)
        for (sortOrder, row) in ordered.enumerated() where row.sortOrder != sortOrder {
            row.sortOrder = sortOrder
        }
    }

    /// Every row with this id, because sync can duplicate one, and a delete that left a twin would bring the item back.
    private static func rows(_ id: TreeNodeID, in context: ModelContext) throws -> [any NamedTreeRow] {
        switch id {
        case .collection(let id): try context.fetch(CollectionModel.withID(id))
        case .folder(let id): try context.fetch(FolderModel.withID(id))
        case .request(let id): try context.fetch(RequestModel.withID(id))
        }
    }

    private static func containerRow(
        _ id: TreeContainerID,
        in context: ModelContext
    ) throws -> TreeContainerRow {
        let row: TreeContainerRow? = switch id {
        case .collection(let id):
            try context.fetch(CollectionModel.withID(id)).first.map { .collection($0) }
        case .folder(let id):
            try context.fetch(FolderModel.withID(id)).first.map { .folder($0) }
        }
        guard let row else {
            throw TreeWriteError.containerNotFound(id)
        }
        return row
    }

    /// Fetches rather than reading a parent's array, which can miss a row a sync has just imported.
    private static func children(
        of container: TreeContainerID,
        in context: ModelContext
    ) throws -> [any TreeChildRow] {
        let folders: [any TreeChildRow] = try context.fetch(FetchDescriptor<FolderModel>())
        let requests: [any TreeChildRow] = try context.fetch(FetchDescriptor<RequestModel>())
        return (folders + requests)
            .filter { $0.container == container }
            .sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
    }

    private static func nextSortOrder(in container: TreeContainerID, context: ModelContext) throws -> Int {
        try (children(of: container, in: context).last?.sortOrder ?? -1) + 1
    }

}
