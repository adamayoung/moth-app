//  WorkspaceModel+Domain.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension WorkspaceModel {

    convenience init(_ workspace: Workspace) throws {
        self.init()
        self.id = workspace.id
        self.activeEnvironmentID = workspace.activeEnvironmentID
        self.collections = try workspace.collections.enumerated().map { index, collection in
            try CollectionModel(collection, sortOrder: index)
        }
        self.environments = workspace.environments.enumerated().map { index, environment in
            EnvironmentModel(environment, sortOrder: index)
        }
        self.globals = workspace.globals.enumerated().map { index, variable in
            VariableModel(variable, sortOrder: index, isGlobal: true)
        }
    }

    public func asDomain() throws -> Workspace {
        try Workspace(
            id: id,
            collections: collections.inSortOrder.map { try $0.asDomain() },
            environments: environments.inSortOrder.map { $0.asDomain() },
            globals: globals.inSortOrder.map { $0.asDomain() },
            activeEnvironmentID: activeEnvironmentID
        )
    }

}
