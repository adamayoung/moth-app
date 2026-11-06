//  StoreWriterTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreWriterTests {

    private struct WriteFailure: Error {}

    @Test("Opening a store and reconciling it creates no workspace")
    func openingCreatesNoWorkspace() async throws {
        let dataModel = try DataModel.inMemory()

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try Self.savedRows(WorkspaceModel.self, in: dataModel).isEmpty)
    }

    @Test("The first collection creates the workspace")
    func firstCollectionCreatesTheWorkspace() async throws {
        let dataModel = try DataModel.inMemory()
        let collection = DomainFixtures.collection()

        try await dataModel.writer.createCollection(collection)

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.collections == [collection])
    }

    @Test("The first environment creates the workspace")
    func firstEnvironmentCreatesTheWorkspace() async throws {
        let dataModel = try DataModel.inMemory()
        let environment = DomainFixtures.environment()

        try await dataModel.writer.createEnvironment(environment)

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.environments == [environment])
    }

    @Test("Later collections and environments join the workspace, in the order they were made")
    func laterRowsReuseTheWorkspace() async throws {
        let dataModel = try DataModel.inMemory()

        try await dataModel.writer.createCollection(RequestCollection(name: "First"))
        try await dataModel.writer.createEnvironment(WorkspaceEnvironment(name: "One"))
        try await dataModel.writer.createCollection(RequestCollection(name: "Second"))
        try await dataModel.writer.createEnvironment(WorkspaceEnvironment(name: "Two"))

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.collections.map(\.name) == ["First", "Second"])
        #expect(workspace.environments.map(\.name) == ["One", "Two"])
    }

    @Test("Two workspaces merge into the lowest id, keeping every child")
    func mergeKeepsEveryChild() async throws {
        let lower = Self.workspace(id: 1)
        let higher = Self.workspace(id: 2)
        let dataModel = try Self.dataModel(holding: [higher, lower])

        try await dataModel.writer.reconcileWorkspaces()

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.id == lower.id)
        #expect(Set(workspace.collections) == Set(lower.collections + higher.collections))
        #expect(Set(workspace.environments) == Set(lower.environments + higher.environments))
        #expect(Set(workspace.globals) == Set(lower.globals + higher.globals))
    }

    @Test("Three workspaces merge into one")
    func mergeHandlesMoreThanTwo() async throws {
        let workspaces = [Self.workspace(id: 3), Self.workspace(id: 1), Self.workspace(id: 2)]
        let dataModel = try Self.dataModel(holding: workspaces)

        try await dataModel.writer.reconcileWorkspaces()

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.id == Self.id(1))
        #expect(workspace.collections.count == workspaces.flatMap(\.collections).count)
    }

    @Test("A merge moves every row beneath a collection and an environment along with it")
    func mergeKeepsNestedRows() async throws {
        let dataModel = try Self.dataModel(holding: [Self.workspace(id: 2), Self.workspace(id: 1)])
        let rowCounts = try Self.rowCounts(in: dataModel)

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try Self.rowCounts(in: dataModel) == rowCounts)
    }

    @Test("The merge keeps the surviving workspace's active environment")
    func mergeKeepsTheActiveEnvironment() async throws {
        var lower = Self.workspace(id: 1)
        var higher = Self.workspace(id: 2)
        lower.activeEnvironmentID = lower.environments.first?.id
        higher.activeEnvironmentID = higher.environments.first?.id
        let dataModel = try Self.dataModel(holding: [lower, higher])

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try Self.onlyWorkspace(in: dataModel).activeEnvironmentID == lower.activeEnvironmentID)
    }

    @Test("A surviving workspace with no active environment takes the next one's")
    func mergeTakesAnActiveEnvironment() async throws {
        var higher = Self.workspace(id: 2)
        higher.activeEnvironmentID = higher.environments.first?.id
        let dataModel = try Self.dataModel(holding: [Self.workspace(id: 1), higher])

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try Self.onlyWorkspace(in: dataModel).activeEnvironmentID == higher.activeEnvironmentID)
    }

    @Test("Reconcile runs after a write batch")
    func writeBatchReconciles() async throws {
        let dataModel = try Self.dataModel(holding: [Self.workspace(id: 2), Self.workspace(id: 1)])
        let collection = RequestCollection(name: "New")

        try await dataModel.writer.createCollection(collection)

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.id == Self.id(1))
        #expect(workspace.collections.contains(collection))
    }

    @Test("A collection, environment and global left with no workspace are adopted")
    func orphansAreAdopted() async throws {
        let collection = RequestCollection(name: "Orphan")
        let environment = WorkspaceEnvironment(name: "Orphan")
        let global = DomainFixtures.variable(named: "orphan")
        let dataModel = try Self.dataModel(holding: [Workspace(id: Self.id(1))])
        try Self.insert(in: dataModel) { context in
            try context.insert(CollectionModel(collection, sortOrder: 0))
            context.insert(EnvironmentModel(environment, sortOrder: 0))
            context.insert(VariableModel(global, sortOrder: 0, isGlobal: true))
        }

        try await dataModel.writer.reconcileWorkspaces()

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.collections == [collection])
        #expect(workspace.environments == [environment])
        #expect(workspace.globals == [global])
    }

    @Test("A variable waiting for its owner to sync is not made a global")
    func variableWithoutOwnerIsLeftAlone() async throws {
        let dataModel = try Self.dataModel(holding: [Workspace(id: Self.id(1))])
        try Self.insert(in: dataModel) { context in
            context.insert(VariableModel(DomainFixtures.variable(named: "waiting"), sortOrder: 0))
        }

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try Self.onlyWorkspace(in: dataModel).globals.isEmpty)
    }

    @Test("With no workspace, reconcile leaves an orphan for the workspace still to sync")
    func orphanWithoutWorkspaceWaits() async throws {
        let dataModel = try DataModel.inMemory()
        try Self.insert(in: dataModel) { context in
            try context.insert(CollectionModel(RequestCollection(name: "Orphan"), sortOrder: 0))
        }

        try await dataModel.writer.reconcileWorkspaces()

        #expect(try Self.savedRows(WorkspaceModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(CollectionModel.self, in: dataModel).count == 1)
    }

    @Test("A failed write leaves nothing behind, and the next write succeeds")
    func failedWriteRollsBack() async throws {
        let dataModel = try DataModel.inMemory()

        await #expect(throws: WriteFailure.self) {
            try await Self.failWriting(with: dataModel.writer)
        }
        try await dataModel.writer.createCollection(RequestCollection(name: "After"))

        let names = try Self.savedRows(CollectionModel.self, in: dataModel).map(\.name)
        #expect(names == ["After"])
    }

    @Test("A failed write of a whole tree leaves none of its rows, and no workspace")
    func failedTreeWriteLeavesNothing() async throws {
        let dataModel = try DataModel.inMemory()
        let collection = DomainFixtures.collection()

        await #expect(throws: WriteFailure.self) {
            try await Self.failWriting(collection, with: dataModel.writer)
        }

        #expect(try Self.savedRows(WorkspaceModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(CollectionModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(FolderModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(RequestModel.self, in: dataModel).isEmpty)
        #expect(try Self.savedRows(VariableModel.self, in: dataModel).isEmpty)
    }

    @Test("A write made while a second context changes a row keeps that change")
    func writeKeepsAChangeFromAnotherContext() async throws {
        let dataModel = try DataModel.inMemory()
        try await dataModel.writer.createCollection(RequestCollection(name: "Before"))
        try Self.insert(in: dataModel) { context in
            let row = try #require(context.fetch(FetchDescriptor<CollectionModel>()).first)
            row.name = "Changed elsewhere"
        }

        try await dataModel.writer.createCollection(RequestCollection(name: "After"))

        let workspace = try Self.onlyWorkspace(in: dataModel)
        #expect(workspace.collections.map(\.name) == ["Changed elsewhere", "After"])
    }

    @Test("A history entry goes in the local store, and synced rows do not")
    func historyGoesInTheLocalStore() async throws {
        let dataModel = try DataModel.inMemory()
        let entry = DomainFixtures.historyEntry()

        try await dataModel.writer.addHistoryEntry(entry)
        try await dataModel.writer.createCollection(RequestCollection(name: "API"))

        let history = try #require(Self.savedRows(HistoryEntryModel.self, in: dataModel).first)
        let collection = try #require(Self.savedRows(CollectionModel.self, in: dataModel).first)
        #expect(try history.asDomain() == entry)
        #expect(history.persistentModelID.storeIdentifier != collection.persistentModelID.storeIdentifier)
    }

    @StoreActor
    private static func failWriting(with writer: StoreWriter) throws {
        try writer.write { context in
            context.insert(CollectionModel())
            throw WriteFailure()
        }
    }

    @StoreActor
    private static func failWriting(_ collection: RequestCollection, with writer: StoreWriter) throws {
        try writer.write { context in
            let row = try CollectionModel(collection, sortOrder: 0)
            context.insert(row)
            row.workspace = try StoreWriter.implicitWorkspace(in: context)
            throw WriteFailure()
        }
    }

    private static func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    private static func workspace(id value: UInt8) -> Workspace {
        Workspace(
            id: id(value),
            collections: [DomainFixtures.collection(named: "Collection \(value)")],
            environments: [DomainFixtures.environment(named: "Environment \(value)")],
            globals: [DomainFixtures.variable(named: "global\(value)")]
        )
    }

    private static func dataModel(holding workspaces: [Workspace]) throws -> DataModel {
        let dataModel = try DataModel.inMemory()
        try insert(in: dataModel) { context in
            for workspace in workspaces {
                try context.insert(WorkspaceModel(workspace))
            }
        }
        return dataModel
    }

    private static func insert(in dataModel: DataModel, _ rows: (ModelContext) throws -> Void) throws {
        let context = ModelContext(dataModel.container)
        try rows(context)
        try context.save()
    }

    private static func onlyWorkspace(in dataModel: DataModel) throws -> Workspace {
        let workspaces = try savedRows(WorkspaceModel.self, in: dataModel)
        #expect(workspaces.count == 1)
        return try #require(workspaces.first).asDomain()
    }

    private static func rowCounts(in dataModel: DataModel) throws -> [Int] {
        try [
            savedRows(CollectionModel.self, in: dataModel).count,
            savedRows(FolderModel.self, in: dataModel).count,
            savedRows(RequestModel.self, in: dataModel).count,
            savedRows(EnvironmentModel.self, in: dataModel).count,
            savedRows(VariableModel.self, in: dataModel).count
        ]
    }

    /// A fresh context, because the rows under test were saved by another one.
    private static func savedRows<Row: PersistentModel>(
        _ type: Row.Type,
        in dataModel: DataModel
    ) throws -> [Row] {
        try ModelContext(dataModel.container).fetch(FetchDescriptor<Row>())
    }

}
