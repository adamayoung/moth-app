//  Workspace.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

public nonisolated struct Workspace: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var collections: [RequestCollection]
    public var environments: [WorkspaceEnvironment]
    public var globals: [Variable]
    public var activeEnvironmentID: UUID?

    public init(
        id: UUID = UUID(),
        collections: [RequestCollection] = [],
        environments: [WorkspaceEnvironment] = [],
        globals: [Variable] = [],
        activeEnvironmentID: UUID? = nil
    ) {
        self.id = id
        self.collections = collections
        self.environments = environments
        self.globals = globals
        self.activeEnvironmentID = activeEnvironmentID
    }

}
