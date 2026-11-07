//  DataModel+SendContext.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public nonisolated struct SendContext: Sendable {

    public let request: Request
    public let scopes: VariableScopes
    public let workspaceID: UUID?

}

public extension DataModel {

    /// The workspace the app shows: the lowest `id`, which reconcile keeps when two Macs each made one.
    var workspaceID: UUID? {
        try? mainContext.fetch(FetchDescriptor<WorkspaceModel>()).map(\.id).min()
    }

    /// Fetches each scope's rows, because a row's to-many arrays go stale on the main context.
    func sendContext(for id: Request.ID, in tree: CollectionTree, environment: UUID?) throws -> SendContext {
        guard let row = try mainContext.fetch(RequestModel.withID(id)).first else {
            throw RequestSendError.requestNotFound
        }
        return try SendContext(
            request: row.asDomain(),
            scopes: VariableScopes(
                collection: variables(in: tree.collectionID(of: .request(id)).map(VariableScope.collection)),
                environment: variables(in: environment.map(VariableScope.environment)),
                globals: variables(in: .globals)
            ),
            workspaceID: workspaceID
        )
    }

    private func variables(in scope: VariableScope?) throws -> [Variable] {
        guard let scope else {
            return []
        }
        return try mainContext.fetch(VariableModel.inScope(scope)).asVariables
    }

}
