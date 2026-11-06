//  StoreWriter+Variables.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public nonisolated enum VariableWriteError: Error, Equatable {

    case scopeNotFound(VariableScope)

}

public extension StoreWriter {

    func addVariable(_ variable: Variable, to scope: VariableScope) throws {
        try write { context in
            let siblings = try context.fetch(FetchDescriptor<VariableModel>()).filter { $0.isIn(scope) }
            let row = VariableModel(variable, sortOrder: siblings.nextSortOrder, isGlobal: scope == .globals)
            context.insert(row)
            try Self.place(row, in: scope, context: context)
        }
    }

    /// Returns the references this leaves unheld, for the caller to remove once the save has landed, because a
    /// `SecItem` call has no place in the synchronous write.
    @discardableResult
    func updateVariable(_ variable: Variable) throws -> Set<SecretReference> {
        try write { context in
            let rows = try context.fetch(VariableModel.withID(variable.id))
            let letGo = rows.filter { $0.secretIdentifier != variable.secretReference?.identifier }
            let released = try Self.secrets(releasedBy: letGo, in: context)
            rows.forEach { $0.apply(variable) }
            return released
        }
    }

    @discardableResult
    func deleteVariable(_ id: UUID) throws -> Set<SecretReference> {
        try write { context in
            let rows = try context.fetch(VariableModel.withID(id))
            let released = try Self.secrets(releasedBy: rows, in: context)
            rows.forEach(context.delete)
            return released
        }
    }

    func renameEnvironment(_ id: UUID, to name: String) throws {
        try write { context in
            for row in try context.fetch(EnvironmentModel.withID(id)) where row.name != name {
                row.name = name
            }
        }
    }

    @discardableResult
    func deleteEnvironment(_ id: UUID) throws -> Set<SecretReference> {
        try write { context in
            let going = try context.fetch(FetchDescriptor<VariableModel>()).filter { $0.isIn(.environment(id)) }
            let released = try Self.secrets(releasedBy: going, in: context)
            try context.fetch(EnvironmentModel.withID(id)).forEach(context.delete)
            return released
        }
    }

    /// Rows can share a reference, and an update or delete of one row must not take a value another still reads.
    private static func secrets(
        releasedBy going: [VariableModel],
        in context: ModelContext
    ) throws -> Set<SecretReference> {
        let goingRows = Set(going.map(\.persistentModelID))
        let held = try context.fetch(FetchDescriptor<VariableModel>())
            .filter { !goingRows.contains($0.persistentModelID) }
            .compactMap(\.secretIdentifier)
        let released = Set(going.compactMap(\.secretIdentifier)).subtracting(held)
        return Set(released.map(SecretReference.init(identifier:)))
    }

    private static func place(_ row: VariableModel, in scope: VariableScope, context: ModelContext) throws {
        switch scope {
        case .globals:
            row.workspace = try implicitWorkspace(in: context)
        case .environment(let id):
            guard let owner = try context.fetch(EnvironmentModel.withID(id)).inSortOrder.first else {
                throw VariableWriteError.scopeNotFound(scope)
            }
            row.environment = owner
        case .collection(let id):
            guard let owner = try context.fetch(CollectionModel.withID(id)).inSortOrder.first else {
                throw VariableWriteError.scopeNotFound(scope)
            }
            row.collection = owner
        }
    }

}
