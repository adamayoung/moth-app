//  EnvironmentSummaryTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct EnvironmentSummaryTests {

    @Test("Summaries follow sort order and count each environment's variables")
    func summariesOrderAndCount() throws {
        let staging = WorkspaceEnvironment(name: "Staging", variables: [.plain("a", "1"), .plain("b", "2")])
        let empty = WorkspaceEnvironment(name: "Empty")
        let dataModel = try DataModel.inMemory(seed: Workspace(
            environments: [staging, empty],
            globals: [.plain("global", "3")]
        ))

        let context = ModelContext(dataModel.container)
        let summaries = try EnvironmentSummary.list(
            environments: context.fetch(FetchDescriptor<EnvironmentModel>()),
            variables: context.fetch(FetchDescriptor<VariableModel>())
        )

        #expect(summaries == [
            EnvironmentSummary(id: staging.id, name: "Staging", variableCount: 2),
            EnvironmentSummary(id: empty.id, name: "Empty", variableCount: 0)
        ])
    }

    @Test("A twin from sync counts once, as an environment and as a variable")
    func twinsCountOnce() throws {
        let variable = Variable.plain("a", "1")
        let environment = WorkspaceEnvironment(name: "Staging", variables: [variable])
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [environment]))
        let context = ModelContext(dataModel.container)
        context.insert(EnvironmentModel(environment, sortOrder: 1))
        try context.save()

        let summaries = try EnvironmentSummary.list(
            environments: context.fetch(FetchDescriptor<EnvironmentModel>()),
            variables: context.fetch(FetchDescriptor<VariableModel>())
        )

        #expect(summaries == [EnvironmentSummary(id: environment.id, name: "Staging", variableCount: 1)])
    }

    @Test("Variables read in sort order with one row per id")
    func variablesReadInOrder() throws {
        let first = Variable.plain("first", "1")
        let second = Variable.plain("second", "2")
        let dataModel = try DataModel.inMemory(seed: Workspace(globals: [first, second]))
        let context = ModelContext(dataModel.container)
        context.insert(VariableModel(first, sortOrder: 9, isGlobal: true))
        try context.save()

        let rows = try context.fetch(VariableModel.inScope(.globals))

        #expect(rows.asVariables == [first, second])
    }

}
