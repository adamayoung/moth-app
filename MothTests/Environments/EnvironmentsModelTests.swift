//  EnvironmentsModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct EnvironmentsModelTests {

    let dataModel: DataModel
    let secretStore = InMemorySecretStore()
    let activeEnvironment = ActiveEnvironment(inMemory: nil)
    let model: EnvironmentsModel

    let secret = SecretReference()
    let staging: WorkspaceEnvironment
    let production = WorkspaceEnvironment(name: "Production")

    init() throws {
        let staging = WorkspaceEnvironment(name: "Staging", variables: [
            Variable(name: "token", value: .secret(secret)),
            Variable(name: "host", value: .plain(initial: "a", current: "b"))
        ])
        self.staging = staging
        self.dataModel = try .inMemory(seed: Workspace(environments: [staging, production]))
        self.model = EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: secretStore,
            activeEnvironment: activeEnvironment
        )
        try deliverRows()
    }

    /// Stands in for `@Query`, which delivers a writer's save to the view some time after the write returns.
    private func deliverRows() throws {
        let context = ModelContext(dataModel.container)
        try model.rowsDidChange(EnvironmentSummary.list(
            environments: context.fetch(FetchDescriptor<EnvironmentModel>()),
            variables: context.fetch(FetchDescriptor<VariableModel>())
        ))
    }

    private var names: [String] {
        model.rows.map(\.name)
    }

    @Test("New Environment adds a row with its name ready to edit")
    func newEnvironment() async throws {
        await model.newEnvironment()
        try deliverRows()

        let row = try #require(model.rows.last)
        #expect(names == ["Staging", "Production", "New Environment"])
        #expect(model.renaming == row.id)
        #expect(model.renameDraft == "New Environment")
    }

    @Test("Committing a rename saves the trimmed name and ends the edit")
    func rename() async throws {
        await model.beginRename(of: staging.id)
        model.renameDraft = "  QA  "

        await model.commitRename(of: staging.id)
        try deliverRows()

        #expect(names == ["QA", "Production"])
        #expect(model.renaming == nil)
    }

    @Test("A rename to nothing keeps the old name")
    func emptyRename() async throws {
        await model.beginRename(of: staging.id)
        model.renameDraft = "   "

        await model.commitRename(of: staging.id)
        try deliverRows()

        #expect(names == ["Staging", "Production"])
        #expect(model.renaming == nil)
    }

    @Test("Cancelling a rename keeps the old name")
    func cancelRename() async throws {
        await model.beginRename(of: staging.id)
        model.renameDraft = "QA"

        model.cancelRename()
        await model.commitRename(of: staging.id)
        try deliverRows()

        #expect(names == ["Staging", "Production"])
    }

    @Test("Beginning a rename commits the one in progress")
    func secondRenameCommitsTheFirst() async throws {
        await model.beginRename(of: staging.id)
        model.renameDraft = "QA"

        await model.beginRename(of: production.id)
        try deliverRows()

        #expect(names == ["QA", "Production"])
        #expect(model.renaming == production.id)
        #expect(model.renameDraft == "Production")
    }

    @Test("A row that goes while it is being renamed ends the edit")
    func deletedRowEndsTheRename() async throws {
        await model.beginRename(of: staging.id)

        try await dataModel.writer.deleteEnvironment(staging.id)
        try deliverRows()

        #expect(model.renaming == nil)
    }

    @Test("A delete waits for confirmation, carrying the row's variable count")
    func deletionWaitsForConfirmation() throws {
        let row = try #require(model.rows.first)

        model.requestDeletion(of: row)

        #expect(model.pendingDeletion?.name == "Staging")
        #expect(model.pendingDeletion?.variableCount == 2)
        #expect(names == ["Staging", "Production"])
    }

    @Test("A confirmed delete removes the row and the secret only it held")
    func confirmedDelete() async throws {
        await secretStore.save("hunter2", for: secret.identifier)
        let row = try #require(model.rows.first)

        await model.confirmDeletion(row)
        try deliverRows()

        #expect(names == ["Production"])
        #expect(await secretStore.value(for: secret.identifier) == nil)
    }

    @Test("Deleting the active environment selects No Environment")
    func deletingTheActiveEnvironment() async throws {
        model.selectActive(staging.id)
        let row = try #require(model.rows.first)

        await model.confirmDeletion(row)
        try deliverRows()

        #expect(model.activeID == nil)
        #expect(activeEnvironment.id == nil)
    }

    @Test("Choosing an environment makes it active")
    func selectActive() {
        model.selectActive(production.id)

        #expect(model.activeID == production.id)
        #expect(activeEnvironment.id == production.id)
    }

    @Test("A choice with no row here reads as No Environment, and stays saved until the row arrives")
    func danglingChoiceReadsAsNone() {
        let notSyncedYet = UUID()
        let active = ActiveEnvironment(inMemory: notSyncedYet)
        let model = EnvironmentsModel(
            writer: dataModel.writer,
            secretStore: secretStore,
            activeEnvironment: active
        )

        model.rowsDidChange([])
        #expect(model.activeID == nil)
        #expect(active.id == notSyncedYet)

        model.rowsDidChange([EnvironmentSummary(id: notSyncedYet, name: "Staging", variableCount: 0)])
        #expect(model.activeID == notSyncedYet)
    }

}
