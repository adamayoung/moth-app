//  WorkspaceModel+Survivor.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension WorkspaceModel {

    /// The lowest `id` survives a merge, the workspace the app shows, and the one whose cookies a send uses.
    static func survives(_ workspace: WorkspaceModel, before other: WorkspaceModel) -> Bool {
        workspace.id < other.id
    }

}

nonisolated extension Sequence<WorkspaceModel> {

    var survivor: WorkspaceModel? {
        self.min(by: WorkspaceModel.survives)
    }

}
