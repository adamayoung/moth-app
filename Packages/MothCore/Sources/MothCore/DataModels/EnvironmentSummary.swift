//  EnvironmentSummary.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// Built from flat `@Query` results, because a row's to-many arrays go stale on the main context.
public nonisolated struct EnvironmentSummary: Identifiable, Hashable, Sendable {

    public let id: UUID
    public let name: String
    public let variableCount: Int

    public init(id: UUID, name: String, variableCount: Int) {
        self.id = id
        self.name = name
        self.variableCount = variableCount
    }

    public static func list(environments: [EnvironmentModel], variables: [VariableModel]) -> [EnvironmentSummary] {
        let owners = variables.oneRowPerID.compactMap(\.environment?.id)
        let counts = Dictionary(owners.map { ($0, 1) }, uniquingKeysWith: +)
        return environments.oneRowPerID.map { row in
            EnvironmentSummary(id: row.id, name: row.name, variableCount: counts[row.id] ?? 0)
        }
    }

}

public nonisolated extension [VariableModel] {

    var asVariables: [Variable] {
        oneRowPerID.map { $0.asDomain() }
    }

}
