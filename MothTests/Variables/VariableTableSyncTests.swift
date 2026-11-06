//  VariableTableSyncTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct VariableTableSyncTests {

    private actor RecordingSecretStore: SecretStore {
        private(set) var values: [String: String] = [:]

        func save(_ value: String, for identifier: String) {
            values[identifier] = value
        }

        func value(for identifier: String) -> String? {
            values[identifier]
        }

        func removeValue(for identifier: String) {
            values[identifier] = nil
        }
    }

    let dataModel: DataModel
    private let secretStore = RecordingSecretStore()
    let model: VariableTableModel

    let host = Variable(name: "host", value: .plain(initial: "one", current: "two"))
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

    private func deliverVariables() throws {
        try model.variablesDidChange(savedVariables)
    }

    private func draft(_ id: UUID) throws -> VariableDraft {
        try #require(model.drafts.first { $0.id == id })
    }

    /// Returns once a commit of `value` is waiting inside the store, with the token loaded as a secret.
    private func tableWithASaveHeld(
        _ store: HoldingSecretStore,
        value: String
    ) async throws -> (table: VariableTableModel, commit: Task<Void, Never>) {
        await store.save("hunter2", for: reference.identifier)
        let table = VariableTableModel(
            scope: .environment(environment.id),
            writer: dataModel.writer,
            secretStore: store
        )
        try table.variablesDidChange(savedVariables)
        await table.loadSecrets()
        table.update(token.id) { $0.secret?.value = .available(value) }
        await store.holdNextSave()
        let commit = Task { await table.commit(token.id) }
        while await !store.isHoldingASave {
            await Task.yield()
        }
        return (table, commit)
    }

    private func letOtherWorkRun() async throws {
        try await Task.sleep(for: .milliseconds(100))
    }

    @Test("A secret another Mac turned plain stays plain, and a name being typed survives")
    func draftFollowsAnotherMacTurningASecretPlain() async throws {
        await secretStore.save("hunter2", for: reference.identifier)
        await model.loadSecrets()
        model.update(token.id) { $0.name = "typing" }

        try await dataModel.writer.updateVariable(
            Variable(id: token.id, name: "token", value: .plain(initial: "hunter2", current: "hunter2")),
            replacing: reference
        )
        try deliverVariables()
        await model.commit(token.id)

        let saved = try #require(savedVariables.last)
        #expect(saved.name == "typing")
        #expect(saved.secretReference == nil)
        #expect(saved.currentValue == "hunter2")
    }

    @Test("A plain row another Mac made secret stays secret, and its value stays in the store")
    func draftFollowsAnotherMacTurningAVariableSecret() async throws {
        let theirs = SecretReference()
        await secretStore.save("hunter2", for: theirs.identifier)
        model.update(host.id) { $0.name = "typing" }

        try await dataModel.writer.updateVariable(
            Variable(id: host.id, name: "host", value: .secret(theirs)),
            replacing: nil
        )
        try deliverVariables()
        await model.commit(host.id)

        let saved = try #require(savedVariables.first)
        #expect(saved.name == "typing")
        #expect(saved.secretReference == theirs)
        #expect(await secretStore.value(for: theirs.identifier) == "hunter2")
    }

    @Test("An edit from before another Mac's secret arrived leaves that secret in the store")
    func staleDraftLeavesTheNewerSecret() async throws {
        let theirs = SecretReference()
        await secretStore.save("hunter2", for: theirs.identifier)
        try await dataModel.writer.updateVariable(
            Variable(id: host.id, name: "host", value: .secret(theirs)),
            replacing: nil
        )
        model.update(host.id) { $0.name = "typing" }

        await model.commit(host.id)

        #expect(await secretStore.value(for: theirs.identifier) == "hunter2")
        #expect(try savedVariables.first?.secretReference == theirs)

        try deliverVariables()
        await model.commit(host.id)

        #expect(try savedVariables.first?.name == "typing")
        #expect(try savedVariables.first?.secretReference == theirs)
    }

    @Test("A later edit to a secret wins, though the save before it is still running")
    func laterEditWins() async throws {
        let store = HoldingSecretStore()
        let (table, firstCommit) = try await tableWithASaveHeld(store, value: "ab")

        table.update(token.id) { $0.secret?.value = .available("abc") }
        let secondCommit = Task { await table.commit(token.id) }
        try await letOtherWorkRun()
        await store.finishHeldSave()
        await firstCommit.value
        await secondCommit.value

        #expect(await store.value(for: reference.identifier) == "abc")
    }

    @Test("Turning off Secret while its last edit saves leaves nothing in the store")
    func turningOffSecretDuringASave() async throws {
        let store = HoldingSecretStore()
        let (table, commit) = try await tableWithASaveHeld(store, value: "ab")

        let turningOff = Task { await table.setSecret(false, for: token.id) }
        try await letOtherWorkRun()
        await store.finishHeldSave()
        await commit.value
        await turningOff.value

        #expect(await store.values.isEmpty)
        #expect(try savedVariables.last?.currentValue == "ab")
    }

    @Test("A draft still follows the store's text when its secret has not changed")
    func draftBeingTypedInKeepsItsText() async throws {
        model.update(host.id) { $0.current = "typing" }

        try await dataModel.writer.updateVariable(
            Variable(id: host.id, name: "host", value: .plain(initial: "one", current: "theirs")),
            replacing: nil
        )
        try deliverVariables()

        #expect(try draft(host.id).current == "typing")
    }

    @Test("Turning on Secret twice at once leaves one value in the store")
    func doubleClickMakesOneSecret() async throws {
        async let first: Void = model.setSecret(true, for: host.id)
        async let second: Void = model.setSecret(true, for: host.id)
        _ = await (first, second)

        let identifier = try #require(savedVariables.first?.secretReference?.identifier)
        #expect(await secretStore.values == [
            identifier: "two"
        ])
    }

    @Test("Turning on Secret for a row that has gone leaves nothing behind")
    func secretForAGoneRowLeavesNothing() async throws {
        try await dataModel.writer.deleteVariable(host.id)

        await model.setSecret(true, for: host.id)

        #expect(await secretStore.values.isEmpty)
        #expect(try draft(host.id).secret == nil)
    }

    @Test("Deleting a collection removes the values of its secret variables")
    func deletingACollectionRemovesItsSecrets() async throws {
        let collection = RequestCollection(name: "API", variables: [Variable(name: "token", value: .secret(reference))])
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [collection]))
        let sidebar = SidebarModel(writer: dataModel.writer, secretStore: secretStore)
        await secretStore.save("hunter2", for: reference.identifier)

        await sidebar.confirmDeletion(
            PendingDeletion(id: .collection(collection.id), name: "API", requestsToMention: nil)
        )

        #expect(await secretStore.values.isEmpty)
    }

}
