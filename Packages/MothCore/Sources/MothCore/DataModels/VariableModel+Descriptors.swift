//  VariableModel+Descriptors.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

nonisolated extension VariableModel {

    static var globals: FetchDescriptor<VariableModel> {
        FetchDescriptor(predicate: #Predicate { $0.isGlobal })
    }

    static func withID(_ id: UUID) -> FetchDescriptor<VariableModel> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

    static func ofRequest(_ id: UUID) -> FetchDescriptor<VariableModel> {
        FetchDescriptor(predicate: #Predicate { $0.request?.id == id })
    }

    /// Reads saved rows only: a predicate over a relationship does not see a context's unsaved changes.
    public static func inScope(_ scope: VariableScope) -> FetchDescriptor<VariableModel> {
        switch scope {
        case .globals:
            globals
        case .environment(let id):
            FetchDescriptor(predicate: #Predicate { $0.environment?.id == id })
        case .collection(let id):
            FetchDescriptor(predicate: #Predicate { $0.collection?.id == id })
        }
    }

}
