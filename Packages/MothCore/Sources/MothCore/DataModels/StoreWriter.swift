//  StoreWriter.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

/// Every write goes through here, in one synchronous step, because a save writes back the whole row as this context
/// last read it. See `docs/architecture.md`, Writing to the Store.
@StoreActor
public final class StoreWriter {

    private let container: ModelContainer

    /// Made on first use, so on this actor: a context made on the main thread stays bound to the main queue.
    private lazy var context: ModelContext = {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }()

    nonisolated init(container: ModelContainer) {
        self.container = container
    }

    public func createCollection(_ collection: RequestCollection) throws {
        try write { context in
            let workspace = try Self.implicitWorkspace(in: context)
            let existing = try context.fetch(FetchDescriptor<CollectionModel>())
            let row = try CollectionModel(collection, sortOrder: existing.nextSortOrder)
            context.insert(row)
            row.workspace = workspace
        }
    }

    public func createEnvironment(_ environment: WorkspaceEnvironment) throws {
        try write { context in
            let workspace = try Self.implicitWorkspace(in: context)
            let existing = try context.fetch(FetchDescriptor<EnvironmentModel>())
            let row = EnvironmentModel(environment, sortOrder: existing.nextSortOrder)
            context.insert(row)
            row.workspace = workspace
        }
    }

    public func reconcileWorkspaces() throws {
        try write { _ in }
    }

    /// A batch and its reconcile share one save, so a failure leaves neither behind. `rollback()` clears the pending
    /// changes, because a fetch does not refresh a row that has them.
    func write<Result>(_ batch: (ModelContext) throws -> Result) throws -> Result {
        do {
            let result = try batch(context)
            try reconcile()
            if context.hasChanges {
                try context.save()
            }
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    func writeLocal<Result>(_ batch: (ModelContext) throws -> Result) throws -> Result {
        do {
            let result = try batch(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    func read<Result>(_ body: (ModelContext) throws -> Result) rethrows -> Result {
        try body(context)
    }

    static func implicitWorkspace(in context: ModelContext) throws -> WorkspaceModel {
        if let workspace = try context.fetch(FetchDescriptor<WorkspaceModel>()).survivor {
            return workspace
        }

        let workspace = WorkspaceModel()
        context.insert(workspace)
        return workspace
    }

    /// Every Mac makes the same choice without talking to the others, because the lowest `id` is the same on each.
    private func reconcile() throws {
        let workspaces = try context.fetch(FetchDescriptor<WorkspaceModel>()).sorted(by: WorkspaceModel.survives)
        guard let survivor = workspaces.first else {
            return
        }

        let duplicates = workspaces.dropFirst()
        try move(FetchDescriptor<CollectionModel>(), \.workspace, to: survivor)
        try move(FetchDescriptor<EnvironmentModel>(), \.workspace, to: survivor)
        try move(VariableModel.globals, \.workspace, to: survivor)
        if survivor.activeEnvironmentID == nil, let active = duplicates.lazy.compactMap(\.activeEnvironmentID).first {
            survivor.activeEnvironmentID = active
        }
        try moveCookies(of: duplicates.map(\.id), to: survivor.id)
        duplicates.forEach(context.delete)
    }

    /// Cookies belong to this Mac, so the merged-away workspace's stay, under the survivor.
    private func moveCookies(of merged: [UUID], to survivor: UUID) throws {
        guard !merged.isEmpty else {
            return
        }
        for row in try context.fetch(FetchDescriptor<CookieModel>()) where merged.contains(row.workspaceID) {
            row.workspaceID = survivor
        }
    }

    /// Fetches the children rather than reading a workspace's array, which can miss a row a sync has just imported.
    /// Compares first because an equal-value assignment still rewrites the row.
    private func move<Row: PersistentModel>(
        _ rows: FetchDescriptor<Row>,
        _ workspace: ReferenceWritableKeyPath<Row, WorkspaceModel?>,
        to survivor: WorkspaceModel
    ) throws {
        for row in try context.fetch(rows)
            where row[keyPath: workspace]?.persistentModelID != survivor.persistentModelID {
            row[keyPath: workspace] = survivor
        }
    }

}
