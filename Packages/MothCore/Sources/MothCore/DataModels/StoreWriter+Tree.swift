//  StoreWriter+Tree.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import SwiftData

public nonisolated enum TreeWriteError: Error, Equatable {

    case containerNotFound(TreeContainerID)

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

    /// Fetches every row and walks its relationship, because a parent's own array can miss a row a sync has just
    /// imported, and a `#Predicate` on a related row's property ignores this context's unsaved changes.
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
