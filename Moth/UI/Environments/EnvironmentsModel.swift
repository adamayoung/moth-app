//  EnvironmentsModel.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Observation
import OSLog

/// Apart from `SidebarModel`, whose selection and rename name tree rows: an environment is not in the tree.
@Observable
final class EnvironmentsModel {

    var pendingDeletion: EnvironmentSummary?
    var renameDraft = ""
    private(set) var renaming: UUID?
    private(set) var rows: [EnvironmentSummary] = []

    private let writer: StoreWriter
    private let secretStore: any SecretStore
    private let activeEnvironment: ActiveEnvironment

    init(writer: StoreWriter, secretStore: any SecretStore, activeEnvironment: ActiveEnvironment) {
        self.writer = writer
        self.secretStore = secretStore
        self.activeEnvironment = activeEnvironment
    }

    /// Nil for a choice with no row here, which stays saved in case the row has yet to sync.
    var activeID: UUID? {
        rows.first { $0.id == activeEnvironment.id }?.id
    }

    func selectActive(_ id: UUID?) {
        activeEnvironment.select(id)
    }

    func rowsDidChange(_ newRows: [EnvironmentSummary]) {
        if let renaming, rows.contains(where: { $0.id == renaming }), !newRows.contains(where: { $0.id == renaming }) {
            self.renaming = nil
        }
        rows = newRows
        activeEnvironment.environmentsDidChange(Set(newRows.map(\.id)))
    }

    func newEnvironment() async {
        await commitActiveRename()
        let environment = WorkspaceEnvironment(name: String(localized: "DEFAULT_ENVIRONMENT_NAME"))
        if await perform({ [writer] in try await writer.createEnvironment(environment) }) {
            renaming = environment.id
            renameDraft = environment.name
        }
    }

    func beginRename(of id: UUID) async {
        await commitActiveRename()
        renaming = id
        renameDraft = rows.first { $0.id == id }?.name ?? ""
    }

    /// Both Return and the field losing focus arrive here, so only the first of them ends the edit.
    func commitRename(of id: UUID) async {
        guard renaming == id else {
            return
        }
        renaming = nil

        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }
        await perform { [writer] in try await writer.renameEnvironment(id, to: name) }
    }

    func cancelRename() {
        renaming = nil
    }

    func requestDeletion(of row: EnvironmentSummary) {
        pendingDeletion = row
    }

    /// The active environment clears when the query delivers the list without this row.
    func confirmDeletion(_ row: EnvironmentSummary) async {
        await perform { [writer, secretStore] in
            try await secretStore.remove(writer.deleteEnvironment(row.id))
        }
    }

    /// A menu click leaves the field focused, so nothing else commits an edit that a new one is about to replace.
    private func commitActiveRename() async {
        if let renaming {
            await commitRename(of: renaming)
        }
    }

    /// A row that failed to change stays as it was on screen, so the sidebar shows the truth.
    @discardableResult
    private func perform(_ write: () async throws -> Void) async -> Bool {
        do {
            try await write()
            return true
        } catch {
            Logger.variables.error("An environment write failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

}
