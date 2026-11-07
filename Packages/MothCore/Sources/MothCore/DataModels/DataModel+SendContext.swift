//  DataModel+SendContext.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public nonisolated struct SendContext: Sendable {

    public let request: Request
    public let scopes: VariableScopes

}

public extension DataModel {

    var workspaceID: UUID? {
        try? mainContext.fetch(FetchDescriptor<WorkspaceModel>()).survivor?.id
    }

    /// Fetches each scope's rows, because a row's to-many arrays go stale on the main context.
    func sendContext(for id: Request.ID, in tree: CollectionTree, environment: UUID?) throws -> SendContext {
        guard let row = try mainContext.fetch(RequestModel.withID(id)).first else {
            throw RequestSendError.requestNotFound
        }
        return try SendContext(
            request: row.asDomain(),
            scopes: variableScopes(collection: tree.collectionID(of: .request(id)), environment: environment)
        )
    }

    /// The scopes a folder's or collection's auth resolves in, for a token the sheet gets before any request sends.
    func variableScopes(
        for container: TreeContainerID,
        in tree: CollectionTree,
        environment: UUID?
    ) throws -> VariableScopes {
        let collectionID: UUID? = switch container {
        case .collection(let id): id
        case .folder: tree.collectionID(of: TreeNodeID(container))
        }
        return try variableScopes(collection: collectionID, environment: environment)
    }

    private func variableScopes(collection: UUID?, environment: UUID?) throws -> VariableScopes {
        try VariableScopes(
            collection: variables(in: collection.map(VariableScope.collection)),
            environment: variables(in: environment.map(VariableScope.environment)),
            globals: variables(in: .globals)
        )
    }

    private func variables(in scope: VariableScope?) throws -> [Variable] {
        guard let scope else {
            return []
        }
        return try mainContext.fetch(VariableModel.inScope(scope)).asVariables
    }

}
