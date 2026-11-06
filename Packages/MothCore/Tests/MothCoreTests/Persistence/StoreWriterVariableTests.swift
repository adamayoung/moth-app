//  StoreWriterVariableTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterVariableTests {

    @Test("A new variable goes last in an environment")
    func newVariableGoesLastInAnEnvironment() async throws {
        let environment = WorkspaceEnvironment(name: "Staging", variables: [.plain("first", "1")])
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [environment]))

        try await dataModel.writer.addVariable(.plain("second", "2"), to: .environment(environment.id))

        #expect(try Self.names(in: .environment(environment.id), of: dataModel) == ["first", "second"])
    }

    @Test("A new variable goes last in a collection")
    func newVariableGoesLastInACollection() async throws {
        let collection = RequestCollection(name: "API", variables: [.plain("first", "1")])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))

        try await dataModel.writer.addVariable(.plain("second", "2"), to: .collection(collection.id))

        #expect(try Self.names(in: .collection(collection.id), of: dataModel) == ["first", "second"])
    }

    @Test("The first global creates the workspace, and is marked as one")
    func firstGlobalCreatesTheWorkspace() async throws {
        let dataModel = try DataModel.inMemory()
        let global = Variable.plain("host", "example.com")

        try await dataModel.writer.addVariable(global, to: .globals)

        let context = ModelContext(dataModel.container)
        let workspace = try #require(context.fetch(FetchDescriptor<WorkspaceModel>()).first)
        #expect(try workspace.asDomain().globals == [global])
    }

    @Test("A variable for an owner that has gone is refused and leaves no row behind")
    func missingOwnerIsRefused() async throws {
        let dataModel = try DataModel.inMemory()
        let scope = VariableScope.environment(UUID())

        await #expect(throws: VariableWriteError.scopeNotFound(scope)) {
            try await dataModel.writer.addVariable(.plain("host", "example.com"), to: scope)
        }

        #expect(try ModelContext(dataModel.container).fetch(FetchDescriptor<VariableModel>()).isEmpty)
    }

    @Test("A scope's descriptor returns only that scope's variables")
    func descriptorKeepsToItsScope() throws {
        let environment = WorkspaceEnvironment(name: "Staging", variables: [.plain("environment", "1")])
        let collection = RequestCollection(name: "API", variables: [.plain("collection", "2")])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            collections: [collection],
            environments: [environment],
            globals: [.plain("global", "3")]
        ))

        #expect(try Self.names(in: .environment(environment.id), of: dataModel) == ["environment"])
        #expect(try Self.names(in: .collection(collection.id), of: dataModel) == ["collection"])
        #expect(try Self.names(in: .globals, of: dataModel) == ["global"])
    }

    @Test("An update changes that variable's fields and leaves its sibling alone")
    func updateChangesOneVariable() async throws {
        let changed = Variable.plain("host", "old")
        let sibling = Variable.plain("port", "80")
        let environment = WorkspaceEnvironment(name: "Staging", variables: [changed, sibling])
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [environment]))
        let updated = Variable(
            id: changed.id,
            name: "base",
            value: .plain(initial: "initial", current: "current"),
            isEnabled: false
        )

        let released = try await dataModel.writer.updateVariable(updated)

        #expect(released.isEmpty)
        #expect(try Self.variables(in: .environment(environment.id), of: dataModel) == [updated, sibling])
    }

    @Test("Turning a variable secret leaves no value in its row, and releases nothing")
    func secretLeavesNoValueInTheRow() async throws {
        let plain = Variable.plain("token", "hunter2")
        let environment = WorkspaceEnvironment(name: "Staging", variables: [plain])
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [environment]))
        let reference = SecretReference()

        let released = try await dataModel.writer.updateVariable(
            Variable(id: plain.id, name: plain.name, value: .secret(reference))
        )

        let row = try #require(ModelContext(dataModel.container).fetch(VariableModel.withID(plain.id)).first)
        #expect(row.initialValue.isEmpty)
        #expect(row.currentValue.isEmpty)
        #expect(row.secretIdentifier == reference.identifier)
        #expect(released.isEmpty)
    }

    @Test("Turning a secret plain releases its reference")
    func plainReleasesTheReference() async throws {
        let reference = SecretReference()
        let secret = Variable(name: "token", value: .secret(reference))
        let dataModel = try DataModel.inMemory(seed: Workspace(globals: [secret]))

        let released = try await dataModel.writer.updateVariable(
            Variable(id: secret.id, name: secret.name, value: .plain(initial: "a", current: "a"))
        )

        #expect(released == [reference])
        #expect(try Self.variables(in: .globals, of: dataModel).first?.currentValue == "a")
    }

    @Test("Renaming a secret keeps its reference, so nothing is released")
    func renamingASecretReleasesNothing() async throws {
        let secret = Variable(name: "token", value: .secret(SecretReference()))
        let dataModel = try DataModel.inMemory(seed: Workspace(globals: [secret]))

        let released = try await dataModel.writer.updateVariable(
            Variable(id: secret.id, name: "renamed", value: secret.value)
        )

        #expect(released.isEmpty)
    }

    @Test("Deleting a variable removes every row with its id, and its sibling stays")
    func deleteRemovesTwins() async throws {
        let deleted = Variable.plain("host", "1")
        let sibling = Variable.plain("port", "2")
        let environment = WorkspaceEnvironment(name: "Staging", variables: [deleted, sibling])
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [environment]))
        try Self.insertTwin(of: deleted, in: environment, of: dataModel)

        try await dataModel.writer.deleteVariable(deleted.id)

        #expect(try Self.variables(in: .environment(environment.id), of: dataModel) == [sibling])
    }

    @Test("Deleting a secret releases its reference, unless another variable holds it")
    func deleteReleasesAnUnheldSecret() async throws {
        let shared = SecretReference()
        let own = SecretReference()
        let first = Variable(name: "first", value: .secret(shared))
        let second = Variable(name: "second", value: .secret(shared))
        let third = Variable(name: "third", value: .secret(own))
        let dataModel = try DataModel.inMemory(seed: Workspace(globals: [first, second, third]))

        #expect(try await dataModel.writer.deleteVariable(first.id).isEmpty)
        #expect(try await dataModel.writer.deleteVariable(third.id) == [own])
        #expect(try await dataModel.writer.deleteVariable(second.id) == [shared])
    }

    @Test("Renaming an environment changes every row with its id")
    func renameEnvironment() async throws {
        let environment = WorkspaceEnvironment(name: "Staging")
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [environment]))

        try await dataModel.writer.renameEnvironment(environment.id, to: "Production")

        let rows = try ModelContext(dataModel.container).fetch(FetchDescriptor<EnvironmentModel>())
        #expect(rows.map(\.name) == ["Production"])
    }

    @Test("Deleting an environment removes its variables and keeps other environments'")
    func deleteEnvironmentCascades() async throws {
        let deleted = WorkspaceEnvironment(name: "Staging", variables: [.plain("host", "1")])
        let kept = WorkspaceEnvironment(name: "Production", variables: [.plain("host", "2")])
        let dataModel = try DataModel.inMemory(seed: Workspace(environments: [deleted, kept]))

        try await dataModel.writer.deleteEnvironment(deleted.id)

        let context = ModelContext(dataModel.container)
        #expect(try context.fetch(FetchDescriptor<EnvironmentModel>()).map(\.name) == ["Production"])
        #expect(try context.fetch(FetchDescriptor<VariableModel>()).map(\.currentValue) == ["2"])
    }

    @Test("Deleting an environment releases its secrets, except one a global still holds")
    func deleteEnvironmentReleasesItsSecrets() async throws {
        let shared = SecretReference()
        let own = SecretReference()
        let environment = WorkspaceEnvironment(name: "Staging", variables: [
            Variable(name: "shared", value: .secret(shared)),
            Variable(name: "own", value: .secret(own))
        ])
        let dataModel = try DataModel.inMemory(seed: Workspace(
            environments: [environment],
            globals: [Variable(name: "shared", value: .secret(shared))]
        ))

        let released = try await dataModel.writer.deleteEnvironment(environment.id)

        #expect(released == [own])
    }

    private static func variables(in scope: VariableScope, of dataModel: DataModel) throws -> [Variable] {
        try ModelContext(dataModel.container).fetch(VariableModel.inScope(scope)).inSortOrder.map { $0.asDomain() }
    }

    private static func insertTwin(
        of variable: Variable,
        in environment: WorkspaceEnvironment,
        of dataModel: DataModel
    ) throws {
        let context = ModelContext(dataModel.container)
        let owner = try #require(context.fetch(EnvironmentModel.withID(environment.id)).first)
        let twin = VariableModel(variable, sortOrder: 9)
        context.insert(twin)
        twin.environment = owner
        try context.save()
    }

    private static func names(in scope: VariableScope, of dataModel: DataModel) throws -> [String] {
        try ModelContext(dataModel.container).fetch(VariableModel.inScope(scope)).inSortOrder.map(\.name)
    }

}
