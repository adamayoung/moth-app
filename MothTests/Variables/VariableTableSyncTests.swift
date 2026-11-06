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

    @Test("A secret another Mac turned plain stays plain, and a name being typed survives")
    func draftFollowsAnotherMacTurningASecretPlain() async throws {
        await secretStore.save("hunter2", for: reference.identifier)
        await model.loadSecrets()
        model.update(token.id) { $0.name = "typing" }

        try await dataModel.writer.updateVariable(
            Variable(id: token.id, name: "token", value: .plain(initial: "hunter2", current: "hunter2"))
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

        try await dataModel.writer.updateVariable(Variable(id: host.id, name: "host", value: .secret(theirs)))
        try deliverVariables()
        await model.commit(host.id)

        let saved = try #require(savedVariables.first)
        #expect(saved.name == "typing")
        #expect(saved.secretReference == theirs)
        #expect(await secretStore.value(for: theirs.identifier) == "hunter2")
    }

    @Test("A draft still follows the store's text when its secret has not changed")
    func draftBeingTypedInKeepsItsText() async throws {
        model.update(host.id) { $0.current = "typing" }

        try await dataModel.writer.updateVariable(
            Variable(id: host.id, name: "host", value: .plain(initial: "one", current: "theirs"))
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
