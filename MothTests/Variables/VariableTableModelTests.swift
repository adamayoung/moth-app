//  VariableTableModelTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct VariableTableModelTests {

    private struct KeychainRefused: Error {}

    private struct RefusingSecretStore: SecretStore {
        func save(_: String, for _: String) async throws {
            throw KeychainRefused()
        }

        func value(for _: String) async throws -> String? {
            nil
        }

        func removeValue(for _: String) async throws {}
    }

    let dataModel: DataModel
    let secretStore = InMemorySecretStore()
    let model: VariableTableModel

    let host = Variable(name: "host", value: .plain(initial: "initial.example", current: "current.example"))
    let reference = SecretReference()
    let token: Variable
    let environment: WorkspaceEnvironment

    init() throws {
        let token = Variable(name: "token", value: .secret(reference))
        let environment = WorkspaceEnvironment(name: "Staging", variables: [host, token])
        self.token = token
        self.environment = environment
        self.dataModel = try .inMemory(seed: Workspace(environments: [environment]))
        self.model = VariableTableModel(
            scope: .environment(environment.id),
            writer: dataModel.writer,
            secretStore: secretStore
        )
        try deliverVariables()
    }

    private var savedVariables: [Variable] {
        get throws {
            let context = ModelContext(dataModel.container)
            return try context.fetch(VariableModel.inScope(.environment(environment.id))).asVariables
        }
    }

    /// Stands in for `@Query`, which delivers a writer's save to the view some time after the write returns.
    private func deliverVariables() throws {
        try model.variablesDidChange(savedVariables)
    }

    private func savedRow(_ id: UUID) throws -> VariableModel {
        let context = ModelContext(dataModel.container)
        return try #require(context.fetch(VariableModel.inScope(.environment(environment.id))).first { $0.id == id })
    }

    private func draft(_ id: UUID) throws -> VariableDraft {
        try #require(model.drafts.first { $0.id == id })
    }

    private func loadedSecret() async throws {
        await secretStore.save("hunter2", for: reference.identifier)
        await model.loadSecrets()
    }

    @Test("Drafts follow the saved variables")
    func draftsFollowTheVariables() {
        #expect(model.drafts.map(\.name) == ["host", "token"])
    }

    @Test("A committed field is saved")
    func committedFieldIsSaved() async throws {
        model.update(host.id) { $0.name = "base" }
        model.update(host.id) { $0.current = "edited.example" }

        await model.commit(host.id)

        let saved = try #require(savedVariables.first)
        #expect(saved.name == "base")
        #expect(saved.currentValue == "edited.example")
        #expect(saved.initialValue == "initial.example")
    }

    @Test("A field is not saved until it is committed")
    func uncommittedFieldIsNotSaved() throws {
        model.update(host.id) { $0.name = "base" }

        #expect(try savedVariables.first?.name == "host")
    }

    @Test("Turning off Enabled saves when it commits")
    func enabledSaves() async throws {
        model.update(host.id) { $0.isEnabled = false }

        await model.commit(host.id)

        #expect(try savedVariables.first?.isEnabled == false)
    }

    @Test("Closing the sheet commits every field still being edited")
    func commitAllSavesEverything() async throws {
        await model.add()
        try deliverVariables()
        let added = try #require(model.drafts.last)
        model.update(host.id) { $0.name = "base" }
        model.update(added.id) { $0.name = "port" }

        await model.commitAll()

        #expect(try savedVariables.map(\.name) == ["base", "token", "port"])
    }

    @Test("A delivery replaces a clean draft and keeps one being edited")
    func deliveryKeepsADirtyDraft() async throws {
        await model.add()
        try deliverVariables()
        let edited = try #require(model.drafts.last)
        model.update(edited.id) { $0.name = "typing" }

        let synced = Variable(id: host.id, name: "synced", value: host.value)
        try await dataModel.writer.updateVariable(synced)
        try await dataModel.writer.updateVariable(Variable(id: edited.id, name: "theirs", value: edited.variable.value))
        try deliverVariables()

        #expect(try draft(host.id).name == "synced")
        #expect(try draft(edited.id).name == "typing")
    }

    @Test("Add saves an empty row straight away, last, so its fields have somewhere to commit")
    func addSavesARow() async throws {
        let added = await model.add()

        #expect(model.drafts.last?.id == added)
        #expect(try savedVariables.map(\.name) == ["host", "token", ""])
    }

    @Test("A delivery that arrives before Add returns does not double the row")
    func addCountsARowOnce() async throws {
        let added = try #require(await model.add())

        try deliverVariables()

        #expect(model.drafts.filter { $0.id == added }.count == 1)
    }

    @Test("Removing a row deletes it")
    func removeDeletes() async throws {
        await model.remove(host.id)

        #expect(model.drafts.map(\.name) == ["token"])
        #expect(try savedVariables.map(\.name) == ["token"])
    }

    @Test("Removing a secret row removes its value from the store")
    func removeSecretRemovesTheValue() async throws {
        try await loadedSecret()

        await model.remove(token.id)

        #expect(await secretStore.value(for: reference.identifier) == nil)
    }

    @Test("Turning on Secret moves the value out of the model and into the store")
    func secretMovesTheValue() async throws {
        await model.setSecret(true, for: host.id)

        let row = try savedRow(host.id)
        let identifier = try #require(row.secretIdentifier)
        #expect(row.initialValue.isEmpty)
        #expect(row.currentValue.isEmpty)
        #expect(await secretStore.value(for: identifier) == "current.example")
        #expect(try draft(host.id).secret?.value == .available("current.example"))
    }

    @Test("Turning on Secret keeps an edit not yet committed")
    func secretTakesTheDraftsValue() async throws {
        model.update(host.id) { $0.current = "typed.example" }

        await model.setSecret(true, for: host.id)

        let identifier = try #require(savedRow(host.id).secretIdentifier)
        #expect(await secretStore.value(for: identifier) == "typed.example")
    }

    @Test("Turning on Secret with no current value moves the initial one")
    func secretFallsBackToInitial() async throws {
        model.update(host.id) { $0.current = "" }

        await model.setSecret(true, for: host.id)

        let identifier = try #require(savedRow(host.id).secretIdentifier)
        #expect(await secretStore.value(for: identifier) == "initial.example")
    }

    @Test("A failed Keychain save leaves the row plain, with its value")
    func refusedSaveLeavesThePlainValue() async throws {
        let model = VariableTableModel(
            scope: .environment(environment.id),
            writer: dataModel.writer,
            secretStore: RefusingSecretStore()
        )
        try model.variablesDidChange(savedVariables)

        await model.setSecret(true, for: host.id)

        #expect(try savedRow(host.id).secretIdentifier == nil)
        #expect(try savedRow(host.id).currentValue == "current.example")
        #expect(model.drafts.first?.secret == nil)
    }

    @Test("Turning off Secret puts the value in both columns and removes it from the store")
    func plainRestoresTheValue() async throws {
        try await loadedSecret()

        await model.setSecret(false, for: token.id)

        let row = try savedRow(token.id)
        #expect(row.secretIdentifier == nil)
        #expect(row.initialValue == "hunter2")
        #expect(row.currentValue == "hunter2")
        #expect(await secretStore.value(for: reference.identifier) == nil)
        #expect(try draft(token.id).secret == nil)
    }

    @Test("A saved secret loads into its draft")
    func secretLoads() async throws {
        try await loadedSecret()

        #expect(try draft(token.id).secret?.value == .available("hunter2"))
        #expect(try draft(token.id).canChangeSecret)
    }

    @Test("A secret that has not reached this Mac reports it, and cannot be turned off")
    func missingSecretIsNotYetAvailable() async throws {
        await model.loadSecrets()

        #expect(try draft(token.id).secret?.value == .notYetAvailable)
        #expect(try !draft(token.id).canChangeSecret)

        await model.setSecret(false, for: token.id)

        #expect(try savedRow(token.id).secretIdentifier == reference.identifier)
    }

    @Test("A secret that arrives later loads the next time the sheet looks")
    func lateSecretLoads() async throws {
        await model.loadSecrets()

        try await loadedSecret()

        #expect(try draft(token.id).secret?.value == .available("hunter2"))
    }

    @Test("Editing a secret saves to the store and leaves the model as it was")
    func secretEditGoesToTheStore() async throws {
        try await loadedSecret()
        model.update(token.id) { $0.secret?.value = .available("rotated") }

        await model.commit(token.id)

        #expect(await secretStore.value(for: reference.identifier) == "rotated")
        #expect(try savedRow(token.id).initialValue.isEmpty)
        #expect(try savedRow(token.id).currentValue.isEmpty)
    }

    @Test("Closing the sheet leaves a secret that never arrived alone")
    func commitAllLeavesAMissingSecret() async throws {
        await model.loadSecrets()

        await model.commitAll()

        #expect(await secretStore.value(for: reference.identifier) == nil)
        #expect(try savedRow(token.id).secretIdentifier == reference.identifier)
    }

    @Test("A delivery keeps a secret's loaded value")
    func deliveryKeepsTheLoadedSecret() async throws {
        try await loadedSecret()

        try await dataModel.writer.updateVariable(Variable(id: token.id, name: "renamed", value: token.value))
        try deliverVariables()

        #expect(try draft(token.id).name == "renamed")
        #expect(try draft(token.id).secret?.value == .available("hunter2"))
    }

}
