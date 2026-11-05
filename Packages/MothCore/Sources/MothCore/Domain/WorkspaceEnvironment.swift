//  WorkspaceEnvironment.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Not `Environment`, which is ambiguous with SwiftUI's in a file importing both modules.
public nonisolated struct WorkspaceEnvironment: Identifiable, Sendable, Hashable {

    public let id: UUID
    public var name: String
    public var variables: [Variable]

    public init(id: UUID = UUID(), name: String, variables: [Variable] = []) {
        self.id = id
        self.name = name
        self.variables = variables
    }

}
