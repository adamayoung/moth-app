//  StoreWriter+Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public nonisolated enum AuthWriteError: Error, Equatable {

    case credentialsChanged

}

nonisolated protocol StoredAuthRow: PersistentModel {

    var authData: Data? { get set }
    var storedAuth: Auth { get throws }

}

extension StoreWriter {

    /// Every row with this id, because sync can duplicate one. Returns the references this leaves unheld, as
    /// `updateRequest(_:with:from:)` does, under the same check of what the caller read.
    @discardableResult
    public func updateAuth(
        of container: TreeContainerID,
        to auth: Auth,
        replacing held: Auth
    ) throws -> Set<SecretReference> {
        try write { context in
            let rows: [any StoredAuthRow] = switch container {
            case .collection(let id): try context.fetch(CollectionModel.withID(id))
            case .folder(let id): try context.fetch(FolderModel.withID(id))
            }
            guard !rows.isEmpty else {
                throw TreeWriteError.containerNotFound(container)
            }
            let released = try Self.credentials(releasedBy: rows, replacing: held, with: auth, in: context)
            let data = try StoredJSON.encode(auth)
            for row in rows where row.authData != data {
                row.authData = data
            }
            return released
        }
    }

    /// Refuses unless a row still holds what the caller read: a sync can land first, and writing over a newer
    /// credential would lose it. Any twin counts, because twins from a sync can hold different references.
    static func credentials(
        releasedBy rows: [any StoredAuthRow],
        replacing held: Auth,
        with auth: Auth,
        in context: ModelContext
    ) throws -> Set<SecretReference> {
        let stored = try rows.map { try $0.storedAuth.secretReferences }
        guard stored.contains(held.secretReferences) else {
            throw AuthWriteError.credentialsChanged
        }
        let letGo = Set(stored.joined()).subtracting(auth.secretReferences)
        guard !letGo.isEmpty else {
            return []
        }
        let others = try authJSON(outside: rows, in: context)
        return letGo.filter { reference in
            !others.contains { $0.range(of: Data(reference.identifier.utf8)) != nil }
        }
    }

    /// Bytes rather than decoded `Auth`, because a row this build can't read may still hold a reference, and keeping an
    /// item by mistake only leaves a stray.
    private static func authJSON(
        outside rows: [any StoredAuthRow],
        in context: ModelContext
    ) throws -> [Data] {
        let changing = Set(rows.map(\.persistentModelID))
        var all: [any StoredAuthRow] = try context.fetch(FetchDescriptor<RequestModel>())
        try all += context.fetch(FetchDescriptor<FolderModel>())
        try all += context.fetch(FetchDescriptor<CollectionModel>())
        return all
            .filter { !changing.contains($0.persistentModelID) }
            .compactMap(\.authData)
    }

}
