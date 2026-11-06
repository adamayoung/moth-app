//  VariableTableModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Observation
import OSLog

/// The sheet edits value drafts and commits each through the writer, because a variable autosaves field by field.
@Observable
final class VariableTableModel {

    let scope: VariableScope
    private(set) var drafts: [VariableDraft] = []

    @ObservationIgnored private var saved: [UUID: Variable] = [:]
    @ObservationIgnored private var savedSecrets: [UUID: String] = [:]
    @ObservationIgnored private var lastWrite: Task<Void, Never>?

    private let writer: StoreWriter
    private let secretStore: any SecretStore

    init(scope: VariableScope, writer: StoreWriter, secretStore: any SecretStore) {
        self.scope = scope
        self.writer = writer
        self.secretStore = secretStore
    }

    /// Keeps a draft that has run ahead of the store, so a sync cannot take text out from under someone typing.
    func variablesDidChange(_ variables: [Variable]) {
        drafts = variables.map { variable in
            guard let draft = drafts.first(where: { $0.id == variable.id }) else {
                return VariableDraft(variable)
            }
            return draft.variable == saved[variable.id] ? merged(variable, into: draft) : rebased(draft, onto: variable)
        }
        saved = Dictionary(variables.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func update(_ id: UUID, _ change: (inout VariableDraft) -> Void) {
        if let index = drafts.firstIndex(where: { $0.id == id }) {
            change(&drafts[index])
        }
    }

    /// A read that fails shows as not yet available, which is the state a person can do nothing about either way.
    func loadSecrets() async {
        for draft in drafts {
            guard let secret = draft.secret, !draft.canChangeSecret else {
                continue
            }
            let value = await storedValue(of: secret.reference)
            update(draft.id) { row in
                guard row.secret?.reference == secret.reference, !row.canChangeSecret else {
                    return
                }
                row.secret?.value = value.map(SecretValue.available) ?? .notYetAvailable
            }
            savedSecrets[draft.id] = value
        }
    }

    func commit(_ id: UUID) async {
        await inOrder { await self.writeDraft(id) }
    }

    private func writeDraft(_ id: UUID) async {
        guard let draft = drafts.first(where: { $0.id == id }) else {
            return
        }
        if draft.variable != saved[id] {
            await save(draft.variable)
        }
        if let secret = draft.secret, case .available(let value) = secret.value, value != savedSecrets[id] {
            await saveSecret(value, for: id, reference: secret.reference)
        }
    }

    /// Done leaves a field focused, so nothing else commits what it holds.
    func commitAll() async {
        for draft in drafts {
            await commit(draft.id)
        }
    }

    @discardableResult
    func add() async -> UUID? {
        let variable = Variable(name: "", value: .plain(initial: "", current: ""))
        do {
            try await writer.addVariable(variable, to: scope)
        } catch {
            Self.log("adding a variable", error)
            return nil
        }
        if !drafts.contains(where: { $0.id == variable.id }) {
            drafts.append(VariableDraft(variable))
            saved[variable.id] = variable
        }
        return variable.id
    }

    func remove(_ id: UUID) async {
        await inOrder { await self.removeRow(id) }
    }

    private func removeRow(_ id: UUID) async {
        do {
            let released = try await writer.deleteVariable(id)
            drafts.removeAll { $0.id == id }
            saved[id] = nil
            savedSecrets[id] = nil
            await secretStore.remove(released)
        } catch {
            Self.log("removing a variable", error)
        }
    }

    func setSecret(_ isSecret: Bool, for id: UUID) async {
        await inOrder { await self.changeSecret(isSecret, for: id) }
    }

    private func changeSecret(_ isSecret: Bool, for id: UUID) async {
        guard let draft = drafts.first(where: { $0.id == id }), draft.canChangeSecret else {
            return
        }
        switch (isSecret, draft.secret?.value) {
        case (true, nil):
            await moveToSecret(draft)
        case (false, .available(let value)):
            await moveToPlain(draft, value: value)
        default:
            break
        }
    }

    /// Keychain calls finish in no set order, so a later edit could land first, or a save could recreate an item a
    /// toggle has just removed.
    private func inOrder(_ write: @escaping () async -> Void) async {
        let previous = lastWrite
        let next = Task {
            await previous?.value
            await write()
        }
        lastWrite = next
        await next.value
    }

    /// Saves the value first: a stray Keychain item is harmless, and a reference with no value would lose it.
    private func moveToSecret(_ draft: VariableDraft) async {
        let value = draft.current.isEmpty ? draft.initial : draft.current
        let reference = SecretReference()
        var secret = draft.variable
        secret.value = .secret(reference)
        do {
            try await secretStore.save(value, for: reference.identifier)
        } catch {
            Self.log("saving a secret", error)
            return
        }
        do {
            let released = try await writer.updateVariable(secret, replacing: nil)
            update(draft.id) { row in
                row.initial = ""
                row.current = ""
                row.secret = SecretDraft(reference: reference, value: .available(value))
            }
            saved[draft.id] = secret
            savedSecrets[draft.id] = value
            await secretStore.remove(released)
        } catch {
            Self.log("marking a variable secret", error)
            await secretStore.remove([reference])
        }
    }

    private func moveToPlain(_ draft: VariableDraft, value: String) async {
        var plain = draft.variable
        plain.value = .plain(initial: value, current: value)
        do {
            let released = try await writer.updateVariable(plain, replacing: draft.secret?.reference)
            update(draft.id) { row in
                row.initial = value
                row.current = value
                row.secret = nil
            }
            saved[draft.id] = plain
            savedSecrets[draft.id] = nil
            await secretStore.remove(released)
        } catch {
            Self.log("making a variable plain", error)
        }
    }

    /// Keeps what was typed, but not a plain or secret kind the store has moved on from: committing that would undo
    /// another Mac's change, and lose a value it has already moved.
    private func rebased(_ draft: VariableDraft, onto variable: Variable) -> VariableDraft {
        guard draft.secret?.reference != variable.secretReference else {
            return draft
        }
        var rebased = VariableDraft(variable)
        rebased.name = draft.name
        rebased.isEnabled = draft.isEnabled
        return rebased
    }

    private func merged(_ variable: Variable, into draft: VariableDraft) -> VariableDraft {
        var merged = VariableDraft(variable)
        if let secret = draft.secret, secret.reference == merged.secret?.reference {
            merged.secret = secret
        }
        return merged
    }

    private func storedValue(of reference: SecretReference) async -> String? {
        do {
            return try await secretStore.value(for: reference.identifier)
        } catch {
            Self.log("reading a secret", error)
            return nil
        }
    }

    private func save(_ variable: Variable) async {
        do {
            let released = try await writer.updateVariable(variable, replacing: saved[variable.id]?.secretReference)
            saved[variable.id] = variable
            await secretStore.remove(released)
        } catch {
            Self.log("saving a variable", error)
        }
    }

    private func saveSecret(_ value: String, for id: UUID, reference: SecretReference) async {
        do {
            try await secretStore.save(value, for: reference.identifier)
            savedSecrets[id] = value
        } catch {
            Self.log("saving a secret", error)
        }
    }

    /// Keeps the error private, because a failed save can describe its row, and a variable's text can be a credential.
    private static func log(_ action: StaticString, _ error: any Error) {
        Logger.variables.error("\(action, privacy: .public) failed: \(String(describing: error), privacy: .private)")
    }

}
